import SwiftUI
import InventoryCore
import AppKit

/// Renders the actual SwiftUI view tree with synthetic state, without screen recording.
@MainActor
enum ScreenshotRenderer {
    static func render(to directory: URL) throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        app.appearance = NSAppearance(named: .aqua)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let working = FileManager.default.temporaryDirectory.appendingPathComponent("storage-tracker-render-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: working) }
        let file = working.appendingPathComponent("inventory.json")
        let model = InventoryViewModel(fileURL: file)
        try save(model, "01-video-intake", in: directory)
        var review = ScanSession(clip: .firstLook, baseline: [])
        try review.begin(); try review.receive(MockRecognitionAdapter.observations(for: .firstLook))
        for index in review.proposals.indices {
            var proposal = review.proposals[index]
            proposal.decision = index == 2 ? .ignore : .add
            if index == 3 { proposal.item.name = "Sewing kit"; proposal.item.itemDescription = "Corrected by you: thread, needles and scissors" }
            try review.revise(proposal)
        }
        model.session = review
        try save(model, "02-human-review", in: directory)
        model.approveScan()
        try save(model, "03-approved-inventory", in: directory)
        var rescan = ScanSession(clip: .revisit, baseline: model.items)
        try rescan.begin(); try rescan.receive(MockRecognitionAdapter.observations(for: .revisit))
        var drill = rescan.proposals[0]
        drill.decision = .update(model.items.first { $0.name == "Cordless drill" }!.id)
        try rescan.revise(drill)
        model.session = rescan; model.showIntake = true; model.notice = nil
        try save(model, "04-rescan-reconciliation", in: directory)
        var lantern = rescan.proposals[1]
        lantern.item.itemDescription = "Orange handle, frosted globe; identity checked during review"
        lantern.decision = .update(model.items.first { $0.name == "Camping lantern" }!.id)
        try rescan.revise(lantern)
        var helmet = rescan.proposals[2]; helmet.decision = .add
        try rescan.revise(helmet)
        model.session = rescan; model.approveScan()
        try save(model, "06-rescan-saved", in: directory)
        var failure = ScanSession(clip: .failure, baseline: model.items)
        try failure.begin(); failure.fail(ScanError.mockFailure.localizedDescription)
        model.session = failure; model.selectedClip = .failure; model.showIntake = true; model.notice = nil
        try save(model, "05-recoverable-error", in: directory)
    }
    private static func save(_ model: InventoryViewModel, _ name: String, in directory: URL) throws {
        let host = NSHostingView(rootView: ContentView(model: model)
            .frame(width: 1280, height: 900).preferredColorScheme(.light))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1280, height: 900),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        host.frame = window.contentView!.bounds
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
        host.layoutSubtreeIfNeeded()
        guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw RenderError.noImage }
        host.cacheDisplay(in: host.bounds, to: bitmap)
        guard let bytes = bitmap.representation(using: .png, properties: [:]) else { throw RenderError.noImage }
        try bytes.write(to: directory.appendingPathComponent(name + ".png"), options: .atomic)
        print("Rendered \(name).png (1280 × 900)")
    }
    private enum RenderError: Error { case noImage }
}
