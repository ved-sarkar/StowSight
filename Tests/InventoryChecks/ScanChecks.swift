import Foundation
import InventoryCore

struct ScanChecks {
    let directory: URL
    var file: URL { directory.appendingPathComponent("scan.json") }
    func review(_ names: [String], baseline: [InventoryItem] = []) throws -> ScanSession {
        var session = ScanSession(clip: .firstLook, baseline: baseline)
        try session.begin()
        try session.receive(names.map { .init(name: $0, detail: "Synthetic", confidence: 0.5, timestamp: "00:02") })
        return session
    }
    func decide(_ session: inout ScanSession, _ index: Int, _ decision: ReviewDecision, separate: Bool = false) throws {
        var proposal = session.proposals[index]; proposal.decision = decision; proposal.confirmedSeparate = separate
        try session.revise(proposal)
    }
    func run() async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        var store = try InventoryStore(fileURL: file)
        var session = try review(["Drill", "Case", "False positive"])
        try expectThrows(try session.commit(to: &store))
        try expectTrue(store.items.isEmpty)
        try decide(&session, 0, .add)
        var corrected = session.proposals[1]; corrected.item.name = "Sewing kit"; corrected.item.location = "Drawer"; corrected.decision = .add
        try session.revise(corrected)
        try decide(&session, 2, .ignore)
        let seen = Date(timeIntervalSince1970: 10000)
        try session.commit(to: &store, at: seen)
        try expectEqual(session.phase, .saved)
        try expectEqual(store.items.map(\.name), ["Drill", "Sewing kit"])
        try expectEqual(store.items.first?.lastSeenDate, seen)
        try expectTrue(store.items.first?.lastUsedDate == nil)
        try expectEqual(try InventoryStore(fileURL: file).items, store.items)
        try expectThrows(try session.commit(to: &store))
        print("PASS: review gate, correction, exclusion, save/reload and double-commit rejection")

        var repeats = try review(["Drill", " drill "])
        try decide(&repeats, 0, .add); try decide(&repeats, 1, .add)
        try expectThrows(try repeats.preparedInventory())
        try decide(&repeats, 0, .add, separate: true); try decide(&repeats, 1, .add, separate: true)
        try expectEqual(try repeats.preparedInventory().count, 2)
        try decide(&repeats, 1, .ignore); try decide(&repeats, 0, .add)
        try expectEqual(try repeats.preparedInventory().count, 1)
        print("PASS: duplicate observations require separate-object confirmation or exclusion")

        let original = store.items
        var rescan = try review(["Drill", "Helmet"], baseline: original)
        try decide(&rescan, 0, .add); try decide(&rescan, 1, .add)
        try expectThrows(try rescan.preparedInventory())
        var matched = rescan.proposals[0]; matched.decision = .update(original[0].id); matched.item.location = "Upper shelf"
        try rescan.revise(matched)
        try expectEqual(rescan.retainedCount, 1)
        try rescan.commit(to: &store)
        try expectEqual(store.items.count, 3)
        try expectEqual(store.items[0].id, original[0].id)
        try expectEqual(store.items[0].location, "Upper shelf")
        try expectEqual(store.items[0].lastUsedDate, original[0].lastUsedDate)
        try expectEqual(store.items[1], original[1])
        print("PASS: explicit rescan match preserves identity; unseen objects remain unchanged")

        var twoMatches = try review(["Drill", "Tool"], baseline: store.items)
        try decide(&twoMatches, 0, .update(original[0].id)); try decide(&twoMatches, 1, .update(original[0].id))
        try expectThrows(try twoMatches.preparedInventory())
        try decide(&twoMatches, 1, .update(UUID()))
        try expectThrows(try twoMatches.preparedInventory())
        print("PASS: competing and nonexistent matches are rejected")

        var stale = try review(["New thing"], baseline: store.items)
        try decide(&stale, 0, .add)
        try store.upsert(InventoryItem(name: "Manual addition"))
        let before = try Data(contentsOf: file)
        try expectThrows(try stale.commit(to: &store))
        try expectEqual(try Data(contentsOf: file), before)
        print("PASS: stale reviews cannot overwrite newer inventory")

        var invalid = try review([""], baseline: store.items)
        try decide(&invalid, 0, .add)
        try expectThrows(try invalid.commit(to: &store))
        try expectEqual(try Data(contentsOf: file), before)
        let blocked = directory.appendingPathComponent("blocked")
        try Data("blocker".utf8).write(to: blocked)
        var blockedStore = try InventoryStore(fileURL: blocked.appendingPathComponent("inventory.json"))
        var retry = try review(["Drill"]); try decide(&retry, 0, .add)
        try expectThrows(try retry.commit(to: &blockedStore))
        try expectEqual(retry.phase, .review); try expectTrue(blockedStore.items.isEmpty)
        try FileManager.default.removeItem(at: blocked)
        try retry.commit(to: &blockedStore)
        try expectEqual(try InventoryStore(fileURL: blockedStore.fileURL).items.count, 1)
        print("PASS: invalid input and failed writes preserve inventory; retry commits once")

        var cancelled = try review(["Discarded"], baseline: store.items)
        cancelled.cancel()
        try expectEqual(cancelled.phase, .cancelled)
        try expectThrows(try cancelled.receive(MockRecognitionAdapter.observations(for: .firstLook)))
        try expectThrows(try cancelled.commit(to: &store))
        try expectEqual(try Data(contentsOf: file), before)
        var inFlight = ScanSession(clip: .firstLook, baseline: [])
        try inFlight.begin(); inFlight.cancel()
        try expectThrows(try inFlight.receive(MockRecognitionAdapter.observations(for: .firstLook)))
        let task = Task { try await MockRecognitionAdapter(delayNanoseconds: 1_000_000_000).recognize(.firstLook) }
        task.cancel()
        do { _ = try await task.value; throw CheckFailure(description: "Cancelled adapter returned data") }
        catch is CancellationError { }
        print("PASS: cancelling recognition or review rejects late results and writes")

        var failed = ScanSession(clip: .failure, baseline: store.items)
        try failed.begin()
        do { _ = try await MockRecognitionAdapter(delayNanoseconds: 0).recognize(.failure); throw CheckFailure(description: "Error fixture succeeded") }
        catch let error as ScanError { failed.fail(error.localizedDescription) }
        try expectEqual(failed.phase, .failed)
        try failed.begin()
        try expectEqual(failed.phase, .recognizing)
        try expectThrows(try failed.receive([]))
        failed.fail(ScanError.emptyScan.localizedDescription)
        try expectEqual(failed.phase, .failed)
        print("PASS: mock error, retry and empty-result recovery")

        var duplicateIDs = ScanSession(clip: .firstLook, baseline: [])
        try duplicateIDs.begin()
        let observation = MockRecognitionAdapter.observations(for: .firstLook)[0]
        try expectThrows(try duplicateIDs.receive([observation, observation]))
        let legacy = "[{\"id\":\"\(UUID().uuidString)\",\"name\":\"Legacy drill\",\"itemDescription\":\"\",\"location\":\"Shelf\",\"estimatedValue\":5,\"lastUsedDate\":1000}]"
        let legacyFile = directory.appendingPathComponent("legacy.json")
        try Data(legacy.utf8).write(to: legacyFile)
        let legacyStore = try InventoryStore(fileURL: legacyFile)
        try expectEqual(legacyStore.items.count, 1)
        try expectTrue(legacyStore.items[0].lastSeenDate == nil)
        try expectTrue(legacyStore.items[0].lastUsedDate != nil)
        print("PASS: invalid observation identifiers rejected; legacy JSON remains readable")
        print("All scan workflow checks passed.")
    }
}
