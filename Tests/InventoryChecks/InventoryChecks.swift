import Foundation
import InventoryCore

final class InventoryChecks {
    private var directory: URL!
    private var file: URL { directory.appendingPathComponent("inventory.json") }

    func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    func testCreateEditMarkUsedAndDeleteSurviveReload() throws {
        var store = try InventoryStore(fileURL: file)
        try expectTrue(store.items.isEmpty)
        var item = InventoryItem(name: "  Fictional toolkit  ", location: "Example shelf", estimatedValue: 12.50,
                                 lastUsedDate: Date(timeIntervalSince1970: 1000))
        try store.upsert(item)
        store = try InventoryStore(fileURL: file)
        try expectEqual(store.items.first?.name, "Fictional toolkit")
        try expectEqual(store.items.first?.estimatedValue, 12.50)
        item.location = "Example cupboard"
        try store.upsert(item)
        let used = Date(timeIntervalSince1970: 2000)
        try store.markUsed(id: item.id, at: used)
        let reloaded = try InventoryStore(fileURL: file)
        try expectEqual(reloaded.items.count, 1)
        try expectEqual(reloaded.items.first?.id, item.id)
        try expectEqual(reloaded.items.first?.location, "Example cupboard")
        try expectEqual(reloaded.items.first?.lastUsedDate, used)
        try store.delete(id: item.id)
        try expectTrue(try InventoryStore(fileURL: file).items.isEmpty)
    }

    func testInvalidChangesPreserveDiskAndMemory() throws {
        var store = try InventoryStore(fileURL: file)
        let valid = InventoryItem(name: "Synthetic item")
        try store.upsert(valid)
        let original = try Data(contentsOf: file)
        for invalid in [InventoryItem(name: " \n"), InventoryItem(name: "Invalid", estimatedValue: -1),
                        InventoryItem(name: "Invalid", estimatedValue: .infinity),
                        InventoryItem(name: "Invalid", estimatedValue: .nan)] {
            try expectThrows(try store.upsert(invalid))
            try expectEqual(store.items, [valid])
            try expectEqual(try Data(contentsOf: file), original)
        }
    }

    func testUnreadableAndDuplicateInventoryAreNotOverwritten() throws {
        let broken = Data("not an inventory".utf8)
        try broken.write(to: file)
        try expectThrows(try InventoryStore(fileURL: file))
        try expectEqual(try Data(contentsOf: file), broken)
        let item = InventoryItem(name: "Synthetic item")
        let duplicate = try JSONEncoder().encode([item, item])
        try duplicate.write(to: file)
        try expectThrows(try InventoryStore(fileURL: file))
        try expectEqual(try Data(contentsOf: file), duplicate)
    }

    func testFailedWriteDoesNotCommitInMemory() throws {
        let parentFile = directory.appendingPathComponent("blocked")
        try Data("synthetic blocker".utf8).write(to: parentFile)
        var store = try InventoryStore(fileURL: parentFile.appendingPathComponent("inventory.json"))
        try expectThrows(try store.upsert(InventoryItem(name: "Synthetic item")))
        try expectTrue(store.items.isEmpty)
    }
}


struct CheckFailure: Error, CustomStringConvertible {
    let description: String
}

func expectTrue(_ condition: Bool, file: StaticString = #fileID, line: UInt = #line) throws {
    guard condition else { throw CheckFailure(description: "Assertion failed at \(file):\(line)") }
}

func expectEqual<T: Equatable>(_ actual: T, _ expected: T,
                                        file: StaticString = #fileID, line: UInt = #line) throws {
    guard actual == expected else { throw CheckFailure(description: "Values differ at \(file):\(line)") }
}

func expectThrows<T>(_ action: @autoclosure () throws -> T,
                             file: StaticString = #fileID, line: UInt = #line) throws {
    do { _ = try action() }
    catch { return }
    throw CheckFailure(description: "Expected an error at \(file):\(line)")
}

@main
struct RunChecks {
    static func main() async throws {
        let checks = InventoryChecks()
        let cases: [(String, () throws -> Void)] = [
            ("CRUD round trip", checks.testCreateEditMarkUsedAndDeleteSurviveReload),
            ("Invalid changes preserve disk and memory", checks.testInvalidChangesPreserveDiskAndMemory),
            ("Unreadable or duplicate records preserve files", checks.testUnreadableAndDuplicateInventoryAreNotOverwritten),
            ("Failed write preserves memory", checks.testFailedWriteDoesNotCommitInMemory)
        ]
        for (name, check) in cases {
            try checks.setUpWithError()
            do {
                try check()
                try checks.tearDownWithError()
                print("PASS: \(name)")
            } catch {
                try? checks.tearDownWithError()
                throw error
            }
        }
        print("All \(cases.count) inventory checks passed.")
        try await ScanChecks(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)).run()
    }
}
