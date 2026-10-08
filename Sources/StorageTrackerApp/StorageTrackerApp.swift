import SwiftUI
import InventoryCore

@main
struct StorageTrackerApp: App {
    @StateObject private var model: InventoryViewModel
    init() {
        if CommandLine.arguments.contains("--check-app") { ApplicationChecks.start() }
        if let index = CommandLine.arguments.firstIndex(of: "--render-screenshots"), CommandLine.arguments.count > index + 1 {
            do { try ScreenshotRenderer.render(to: URL(fileURLWithPath: CommandLine.arguments[index + 1])) }
            catch { print("Screenshot rendering failed: \(error)"); exit(1) }
            exit(0)
        }
        let index = CommandLine.arguments.firstIndex(of: "--data")
        let file = index.flatMap { CommandLine.arguments.count > $0 + 1 ? URL(fileURLWithPath: CommandLine.arguments[$0 + 1]) : nil }
        _model = StateObject(wrappedValue: InventoryViewModel(fileURL: file))
    }
    var body: some Scene {
        WindowGroup("StowSight") {
            ContentView(model: model).frame(minWidth: 1050, minHeight: 780)
        }.defaultSize(width: 1200, height: 880)
    }
}

@MainActor
final class InventoryViewModel: ObservableObject {
    @Published private(set) var items: [InventoryItem] = []
    @Published var session: ScanSession?
    @Published var selectedClip: DemoClip = .firstLook
    @Published var showIntake = true
    @Published var errorMessage: String?
    @Published var notice: String?
    private var store: InventoryStore?
    private var recognitionTask: Task<Void, Never>?
    private let adapter: any RecognitionAdapter
    var canSave: Bool { store != nil }
    var isScanning: Bool { session?.phase == .recognizing }
    var isReviewing: Bool { session?.phase == .review }
    var isBusy: Bool { isScanning || isReviewing }

    init(fileURL: URL? = nil, adapter: any RecognitionAdapter = MockRecognitionAdapter()) {
        self.adapter = adapter
        do {
            let file = fileURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("StorageTrackerDemo/inventory.json")
            store = try InventoryStore(fileURL: file)
            items = store?.items ?? []
            showIntake = items.isEmpty
        } catch { errorMessage = "Could not read the local inventory. Editing is disabled and the original file is untouched." }
    }
    func startScan() {
        guard canSave, !isBusy else { return }
        errorMessage = nil; notice = nil
        var next = ScanSession(clip: selectedClip, baseline: items)
        do { try next.begin() } catch { errorMessage = error.localizedDescription; return }
        session = next; showIntake = true
        let token = next.id
        let clip = selectedClip
        recognitionTask = Task {
            do {
                let observations = try await adapter.recognize(clip)
                guard !Task.isCancelled, self.session?.id == token else { return }
                try self.session?.receive(observations)
            } catch is CancellationError { /* Cancellation deliberately leaves inventory untouched. */ }
            catch {
                guard self.session?.id == token else { return }
                self.session?.fail(error.localizedDescription)
            }
        }
    }
    func cancelScan() {
        recognitionTask?.cancel(); recognitionTask = nil
        session?.cancel(); session = nil
        notice = "Scan discarded. Your saved inventory is unchanged."
    }
    func revise(_ proposal: ReviewProposal) {
        do { try session?.revise(proposal); errorMessage = nil }
        catch { errorMessage = error.localizedDescription }
    }
    func approveScan() {
        guard var next = session, var storage = store else { return }
        do {
            try next.commit(to: &storage)
            store = storage; items = storage.items; session = next; showIntake = false
            errorMessage = nil; notice = "Review saved locally. Unseen inventory items were kept."
        } catch { errorMessage = error.localizedDescription }
    }
    @discardableResult func save(_ item: InventoryItem) -> Bool {
        guard !isBusy else { return false }
        return change { try $0.upsert(item) }
    }
    func delete(_ item: InventoryItem) { guard !isBusy else { return }; _ = change { try $0.delete(id: item.id) } }
    func markUsed(_ item: InventoryItem) { guard !isBusy else { return }; _ = change { try $0.markUsed(id: item.id) } }
    private func change(_ action: (inout InventoryStore) throws -> Void) -> Bool {
        guard var next = store else { return false }
        do { try action(&next); store = next; items = next.items; errorMessage = nil; return true }
        catch { errorMessage = "Save failed: \(error.localizedDescription) Previous inventory is unchanged."; return false }
    }
}
