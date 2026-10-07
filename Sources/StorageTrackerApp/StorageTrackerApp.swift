import SwiftUI
import InventoryCore

@main
struct StorageTrackerApp: App {
    @StateObject private var model = InventoryViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .frame(minWidth: 620, minHeight: 440)
        }
    }
}

@MainActor
final class InventoryViewModel: ObservableObject {
    @Published private(set) var items: [InventoryItem] = []
    @Published var errorMessage: String?
    private var store: InventoryStore?

    var canSave: Bool { store != nil }

    init() {
        do {
            let support = try FileManager.default.url(for: .applicationSupportDirectory,
                                                      in: .userDomainMask,
                                                      appropriateFor: nil, create: false)
            let file = support.appendingPathComponent("StorageTracker", isDirectory: true)
                .appendingPathComponent("inventory.json")
            store = try InventoryStore(fileURL: file)
            items = store?.items ?? []
        } catch {
            errorMessage = "Could not read the local inventory. The existing file was left untouched."
        }
    }

    @discardableResult
    func save(_ item: InventoryItem) -> Bool { change { try $0.upsert(item) } }

    func delete(_ item: InventoryItem) { change { try $0.delete(id: item.id) } }
    func markUsed(_ item: InventoryItem) { change { try $0.markUsed(id: item.id) } }

    @discardableResult
    private func change(_ action: (inout InventoryStore) throws -> Void) -> Bool {
        guard var next = store else { return false }
        do {
            try action(&next)
            store = next
            items = next.items
            errorMessage = nil
            return true
        } catch let error as InventoryError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Could not save this change. Your previous inventory is still shown."
        }
        return false
    }
}
