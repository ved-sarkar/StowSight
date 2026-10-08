import Foundation

public enum DemoClip: String, CaseIterable, Identifiable, Codable {
    case firstLook, revisit, failure
    public var id: String { rawValue }
    public var title: String {
        switch self { case .firstLook: return "First pass through the storage room"
        case .revisit: return "Another look at the storage room"
        case .failure: return "Recognition error example" }
    }
    public var subtitle: String {
        switch self { case .firstLook: return "12 seconds · 4 synthetic proposals"
        case .revisit: return "9 seconds · 3 synthetic proposals"
        case .failure: return "Test retry and cancellation" }
    }
}

public struct RecognitionObservation: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var detail: String
    public var location: String
    public var confidence: Double
    public var timestamp: String
    public init(id: UUID = UUID(), name: String, detail: String, location: String = "Storage room · Mixed box",
                confidence: Double, timestamp: String) {
        self.id = id; self.name = name; self.detail = detail; self.location = location
        self.confidence = confidence; self.timestamp = timestamp
    }
}

/// The production adapter must return untrusted observations, never mutate inventory.
public protocol RecognitionAdapter: Sendable {
    func recognize(_ clip: DemoClip) async throws -> [RecognitionObservation]
}

/// Deterministic fixtures only: no media is opened, no network or credentials are used.
public struct MockRecognitionAdapter: RecognitionAdapter {
    public var delayNanoseconds: UInt64
    public init(delayNanoseconds: UInt64 = 900_000_000) { self.delayNanoseconds = delayNanoseconds }
    public func recognize(_ clip: DemoClip) async throws -> [RecognitionObservation] {
        try await Task.sleep(nanoseconds: delayNanoseconds)
        try Task.checkCancellation()
        if clip == .failure { throw ScanError.mockFailure }
        return Self.observations(for: clip)
    }
    public static func observations(for clip: DemoClip) -> [RecognitionObservation] {
        switch clip {
        case .firstLook:
            return [
                .init(name: "Cordless drill", detail: "Blue body, black battery", confidence: 0.96, timestamp: "00:02"),
                .init(name: "Camping lantern", detail: "Orange handle, frosted globe", confidence: 0.88, timestamp: "00:05"),
                .init(name: "Cordless drill", detail: "Possibly the same drill from another angle", confidence: 0.67, timestamp: "00:08"),
                .init(name: "Small case", detail: "Label unreadable; confirm what is inside", confidence: 0.48, timestamp: "00:10")
            ]
        case .revisit:
            return [
                .init(name: "Cordless drill", detail: "Blue body, now beside the tool crate", location: "Storage room · Tool crate", confidence: 0.93, timestamp: "00:02"),
                .init(name: "Camping lantern", detail: "Orange handle; identity needs confirmation", confidence: 0.80, timestamp: "00:04"),
                .init(name: "Bike helmet", detail: "Matte blue shell", confidence: 0.91, timestamp: "00:07")
            ]
        case .failure: return []
        }
    }
}

public enum ReviewDecision: Equatable {
    case pending, add, update(UUID), ignore
}

public struct ReviewProposal: Identifiable, Equatable {
    public let id: UUID
    public var observation: RecognitionObservation
    public var item: InventoryItem
    public var decision: ReviewDecision = .pending
    /// Only an explicit user action can acknowledge a potentially separate object.
    public var confirmedSeparate = false
    public init(_ observation: RecognitionObservation) {
        id = observation.id; self.observation = observation
        item = InventoryItem(name: observation.name, itemDescription: observation.detail, location: observation.location)
    }
}

public enum ScanError: LocalizedError {
    case invalidTransition, pendingReview, ambiguousAddition, repeatedMatch, staleInventory, mockFailure, emptyScan
    public var errorDescription: String? {
        switch self {
        case .invalidTransition: return "This scan is no longer ready for that action."
        case .pendingReview: return "Choose Add, Match, or Exclude for every proposal before saving."
        case .ambiguousAddition: return "A similar name already exists. Confirm this is a separate object or choose a match."
        case .repeatedMatch: return "Two proposals target the same inventory item. Exclude the repeated observation."
        case .staleInventory: return "Inventory changed since this scan began. Cancel and start a new scan before saving."
        case .mockFailure: return "The mock adapter returned a test error. Retry, select another demo clip, or cancel."
        case .emptyScan: return "No proposals were found. Your inventory has not changed."
        }
    }
}

public enum ScanPhase: String { case intake, recognizing, review, saved, cancelled, failed }

public struct ScanSession {
    public let id = UUID()
    public let clip: DemoClip
    public let baseline: [InventoryItem]
    public private(set) var phase: ScanPhase = .intake
    public private(set) var proposals: [ReviewProposal] = []
    public private(set) var errorMessage: String?
    public init(clip: DemoClip, baseline: [InventoryItem]) { self.clip = clip; self.baseline = baseline }
    public mutating func begin() throws {
        guard phase == .intake || phase == .failed else { throw ScanError.invalidTransition }
        phase = .recognizing; errorMessage = nil
    }
    public mutating func receive(_ observations: [RecognitionObservation]) throws {
        guard phase == .recognizing else { throw ScanError.invalidTransition }
        guard !observations.isEmpty else { throw ScanError.emptyScan }
        guard Set(observations.map(\.id)).count == observations.count else { throw InventoryError.duplicateID }
        proposals = observations.map(ReviewProposal.init); phase = .review
    }
    public mutating func fail(_ message: String) {
        guard phase == .recognizing else { return }
        phase = .failed; errorMessage = message
    }
    public mutating func cancel() {
        guard phase != .saved else { return }
        phase = .cancelled; proposals = []; errorMessage = nil
    }
    public mutating func revise(_ proposal: ReviewProposal) throws {
        guard phase == .review, let index = proposals.firstIndex(where: { $0.id == proposal.id }) else {
            throw ScanError.invalidTransition
        }
        proposals[index] = proposal
    }
    public func similarItems(to proposal: ReviewProposal) -> [InventoryItem] {
        baseline.filter { Self.key($0.name) == Self.key(proposal.item.name) }
    }
    public func hasDuplicateProposal(_ proposal: ReviewProposal) -> Bool {
        proposals.contains { $0.id != proposal.id && $0.decision != .ignore && Self.key($0.item.name) == Self.key(proposal.item.name) }
    }
    public var pendingCount: Int { proposals.filter { $0.decision == .pending }.count }
    public var retainedCount: Int {
        let matched = Set(proposals.compactMap { p -> UUID? in if case .update(let id) = p.decision { return id }; return nil })
        return baseline.filter { !matched.contains($0.id) }.count
    }
    public func preparedInventory(at date: Date = Date()) throws -> [InventoryItem] {
        guard phase == .review else { throw ScanError.invalidTransition }
        guard pendingCount == 0 else { throw ScanError.pendingReview }
        var next = baseline
        var matched = Set<UUID>()
        for proposal in proposals {
            switch proposal.decision {
            case .pending: throw ScanError.pendingReview
            case .ignore: continue
            case .add:
                guard proposal.confirmedSeparate || (similarItems(to: proposal).isEmpty && !hasDuplicateProposal(proposal)) else {
                    throw ScanError.ambiguousAddition
                }
                var item = proposal.item
                item.lastSeenDate = date
                next.append(item)
            case .update(let id):
                guard matched.insert(id).inserted else { throw ScanError.repeatedMatch }
                guard let index = next.firstIndex(where: { $0.id == id }) else { throw InventoryError.missingItem }
                // Recognition changes reviewed fields only, preserving identity, value and last-used history.
                next[index].name = proposal.item.name
                next[index].itemDescription = proposal.item.itemDescription
                next[index].location = proposal.item.location
                next[index].lastSeenDate = date
            }
        }
        return try InventoryStore.validated(next)
    }
    public mutating func commit(to store: inout InventoryStore, at date: Date = Date()) throws {
        guard store.items == baseline else { throw ScanError.staleInventory }
        let next = try preparedInventory(at: date)
        try store.replaceAll(next)
        phase = .saved
    }
    private static func key(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }
}
