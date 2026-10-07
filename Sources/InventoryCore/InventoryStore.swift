import Foundation

public struct InventoryItem: Codable, Equatable, Identifiable {
    public let id: UUID
    public var name: String
    public var itemDescription: String
    public var location: String
    public var estimatedValue: Double
    public var lastUsedDate: Date

    public init(id: UUID = UUID(), name: String, itemDescription: String = "",
                location: String = "", estimatedValue: Double = 0,
                lastUsedDate: Date = Date()) {
        self.id = id
        self.name = name
        self.itemDescription = itemDescription
        self.location = location
        self.estimatedValue = estimatedValue
        self.lastUsedDate = lastUsedDate
    }
}

public enum InventoryError: LocalizedError {
    case emptyName, invalidValue, duplicateID, missingItem

    public var errorDescription: String? {
        switch self {
        case .emptyName: return "Enter an item name."
        case .invalidValue: return "Enter a finite, nonnegative estimated value."
        case .duplicateID: return "The inventory contains duplicate item identifiers."
        case .missingItem: return "This item is no longer in the inventory."
        }
    }
}

/// A small local store. Memory changes only after the complete file saves successfully.
public struct InventoryStore {
    public private(set) var items: [InventoryItem]
    public let fileURL: URL

    public init(fileURL: URL) throws {
        self.fileURL = fileURL
        if FileManager.default.fileExists(atPath: fileURL.path) {
            items = try JSONDecoder().decode([InventoryItem].self, from: Data(contentsOf: fileURL))
            items = try Self.validated(items)
        } else {
            items = []
        }
    }

    public mutating func upsert(_ item: InventoryItem) throws {
        var next = items
        if let index = next.firstIndex(where: { $0.id == item.id }) {
            next[index] = item
        } else {
            next.append(item)
        }
        try persist(next)
    }

    public mutating func delete(id: UUID) throws {
        guard items.contains(where: { $0.id == id }) else { throw InventoryError.missingItem }
        try persist(items.filter { $0.id != id })
    }

    public mutating func markUsed(id: UUID, at date: Date = Date()) throws {
        guard var item = items.first(where: { $0.id == id }) else { throw InventoryError.missingItem }
        item.lastUsedDate = date
        try upsert(item)
    }

    private static func validated(_ items: [InventoryItem]) throws -> [InventoryItem] {
        guard Set(items.map(\.id)).count == items.count else { throw InventoryError.duplicateID }
        return try items.map { item in
            var clean = item
            clean.name = clean.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.name.isEmpty else { throw InventoryError.emptyName }
            guard clean.estimatedValue.isFinite, clean.estimatedValue >= 0 else {
                throw InventoryError.invalidValue
            }
            return clean
        }
    }

    private mutating func persist(_ next: [InventoryItem]) throws {
        let clean = try Self.validated(next)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(clean)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
        items = clean
    }
}
