import AppKit
import Foundation
import InventoryCore

@MainActor
enum ApplicationChecks {
    static func start() -> Never {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        Task { @MainActor in
            do { try await run(); exit(0) }
            catch { print("FAIL: \(error)"); exit(1) }
        }
        app.run()
        exit(1)
    }
    private static func run() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("storage-tracker-app-check-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("inventory.json")
        let model = InventoryViewModel(fileURL: file, adapter: MockRecognitionAdapter(delayNanoseconds: 10_000_000))
        try require(model.items.isEmpty && model.canSave, "Empty app launch")
        model.startScan()
        try require(model.isScanning && model.items.isEmpty, "Scanning does not save")
        try require(!model.save(InventoryItem(name: "Blocked during recognition")), "Manual edit guard")
        try await wait { model.isReviewing }
        model.approveScan()
        try require(model.items.isEmpty && model.errorMessage != nil, "Pending decisions block approval")
        model.cancelScan()
        try require(model.session == nil && model.items.isEmpty, "Discard review")
        model.selectedClip = .failure; model.startScan()
        try await wait { model.session?.phase == .failed }
        model.startScan()
        try require(model.isScanning, "Retry starts recognition")
        model.cancelScan()
        try await Task.sleep(nanoseconds: 30_000_000)
        try require(model.session == nil && model.items.isEmpty, "Cancel pending failure")
        model.selectedClip = .firstLook; model.startScan()
        try await wait { model.isReviewing }
        for (index, current) in (model.session?.proposals ?? []).enumerated() {
            var proposal = current; proposal.decision = index == 2 ? .ignore : .add
            if index == 3 { proposal.item.name = "Sewing kit" }
            model.revise(proposal)
        }
        model.approveScan()
        try require(model.items.count == 3 && !model.showIntake && model.session?.phase == .saved, "Approval reaches inventory")
        let reloaded = InventoryViewModel(fileURL: file)
        try require(reloaded.items == model.items && !reloaded.showIntake, "Relaunch restores inventory")
        let deleted = reloaded.items[0]
        reloaded.delete(deleted)
        try require(reloaded.items.count == 2 && !reloaded.items.contains { $0.id == deleted.id }, "Explicit manual deletion")
        print("PASS: app model intake, pending gate, discard, error/retry/cancel, approval, reload and manual delete")

        let stubborn = InventoryViewModel(fileURL: root.appendingPathComponent("late.json"), adapter: LateAdapter())
        stubborn.startScan(); stubborn.cancelScan(); stubborn.selectedClip = .revisit; stubborn.startScan()
        try await wait { stubborn.isReviewing }
        try require(stubborn.session?.clip == .revisit && stubborn.session?.proposals.count == 3, "Old cancelled response cannot replace new session")
        print("PASS: non-cooperative adapter late response is ignored")

        let corrupt = root.appendingPathComponent("corrupt.json")
        let bytes = Data("broken".utf8); try bytes.write(to: corrupt)
        let damaged = InventoryViewModel(fileURL: corrupt)
        damaged.startScan()
        try require(!damaged.canSave && damaged.session == nil, "Corrupt store blocks recognition/write")
        try require(try Data(contentsOf: corrupt) == bytes, "Corrupt file preserved")
        let blocker = root.appendingPathComponent("blocker")
        try bytes.write(to: blocker)
        let failing = InventoryViewModel(fileURL: blocker.appendingPathComponent("inventory.json"), adapter: MockRecognitionAdapter(delayNanoseconds: 0))
        failing.startScan(); try await wait { failing.isReviewing }
        for (index, current) in (failing.session?.proposals ?? []).enumerated() {
            var proposal = current; proposal.decision = index == 2 ? .ignore : .add; failing.revise(proposal)
        }
        failing.approveScan()
        try require(failing.isReviewing && failing.items.isEmpty && failing.errorMessage != nil, "Failed save retains draft")
        try FileManager.default.removeItem(at: blocker)
        failing.approveScan()
        try require(failing.items.count == 3 && !failing.showIntake, "Retry successful save")
        print("PASS: app corrupt-store protection and failed-save draft recovery")
        print("All app integration checks passed.")
    }
    private static func wait(_ condition: () -> Bool) async throws {
        for _ in 0..<100 {
            if condition() { return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        throw Failure(message: "Timed out waiting for app state")
    }
    private static func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw Failure(message: message) }
    }
    private struct Failure: Error { let message: String }
    private struct LateAdapter: RecognitionAdapter {
        func recognize(_ clip: DemoClip) async throws -> [RecognitionObservation] {
            try? await Task.sleep(nanoseconds: 10_000_000)
            return MockRecognitionAdapter.observations(for: clip)
        }
    }
}
