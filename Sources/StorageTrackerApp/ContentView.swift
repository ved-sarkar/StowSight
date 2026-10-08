import SwiftUI
import InventoryCore

private let ink = Color(red: 0.12, green: 0.13, blue: 0.23)
private let accent = Color(red: 0.28, green: 0.26, blue: 0.76)
private let canvas = Color(red: 0.97, green: 0.96, blue: 0.98)
private let amber = Color(red: 0.57, green: 0.32, blue: 0.06)

struct ContentView: View {
    @ObservedObject var model: InventoryViewModel
    @State private var editingItem: InventoryItem?
    @State private var pendingDeletion: InventoryItem?
    var body: some View {
        HStack(spacing: 0) {
            sidebar
            VStack(alignment: .leading, spacing: 22) {
                header
                if let error = model.errorMessage { banner(error, color: .red) }
                if let notice = model.notice { banner(notice, color: accent) }
                if model.showIntake {
                    if let session = model.session, session.phase == .review { review(session) }
                    else if model.isScanning { progress }
                    else { ScrollView { intake } }
                } else { inventory }
                Spacer(minLength: 0)
                HStack {
                    Image(systemName: "lock.shield")
                    Text("On this Mac · Synthetic data · No media uploaded")
                    Spacer()
                    Text("Gemini integration planned")
                }.font(.caption).foregroundStyle(.secondary)
            }.padding(32).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(canvas).foregroundStyle(ink).tint(accent)
        .sheet(item: $editingItem) { item in ItemEditor(item: item, save: model.save) }
        .alert("Delete \(pendingDeletion?.name ?? "item")?", isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } })) {
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
            Button("Delete", role: .destructive) { if let item = pendingDeletion { model.delete(item) }; pendingDeletion = nil }
        } message: { Text("Only this explicit action removes the saved item from your local inventory.") }
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(spacing: 10) {
                Image(systemName: "shippingbox.fill").font(.title).foregroundStyle(accent)
                Text("StowSight").font(.title2.weight(.bold))
            }
            Text("Scan your space.\nKnow what’s stored.").font(.subheadline).foregroundStyle(.secondary)
            VStack(spacing: 10) {
                navButton("Video intake", icon: "video", selected: model.showIntake) { model.showIntake = true }
                navButton("Inventory", icon: "square.grid.2x2", selected: !model.showIntake) { model.showIntake = false }
            }
            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                Label("OFFLINE DEMO", systemImage: "sparkles").font(.caption.weight(.bold)).foregroundStyle(accent)
                Text("Try the full review flow with built-in synthetic clips.").font(.callout)
                Text("No camera or AI service is connected.").font(.caption).foregroundStyle(.secondary)
            }.padding(16).background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 16))
        }.padding(24).frame(width: 210).background(Color(red: 0.91, green: 0.90, blue: 0.97))
    }
    private func navButton(_ title: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack { Image(systemName: icon); Text(title); Spacer() }
                .padding(12).background(selected ? accent : .clear, in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(selected ? .white : ink)
        }.buttonStyle(.plain).disabled(model.isBusy)
    }
    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(model.isReviewing ? "You have the final say." : model.showIntake ? "A clearer picture of your space." : "Know what’s stored.")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text(model.isReviewing ? "Correct the details, then decide what belongs in your inventory." : model.showIntake ? "Select a demo clip. Review suggestions. Save only what you approve." : "Your approved belongings, ready for the next time you need them.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(model.items.count) saved items").font(.caption.weight(.semibold)).padding(10)
                .background(.white, in: Capsule())
        }
    }
    private var intake: some View {
        VStack(alignment: .leading, spacing: 22) {
            steps(active: 1)
            HStack(alignment: .top, spacing: 22) {
                StorageIllustration().frame(width: 305, height: 270)
                    .overlay(alignment: .bottomLeading) { Text("SYNTHETIC STORYBOARD · NO VIDEO FILE").font(.system(size: 9, weight: .bold)).padding(14) }
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                VStack(alignment: .leading, spacing: 14) {
                    Text("Choose a demo clip").font(.title2.bold())
                    Text("Explore a storage room with mixed belongings. All suggestions here are synthetic.").foregroundStyle(.secondary)
                    ForEach(DemoClip.allCases) { clip in
                        Button { model.selectedClip = clip } label: {
                            HStack {
                                Image(systemName: model.selectedClip == clip ? "largecircle.fill.circle" : "circle")
                                VStack(alignment: .leading, spacing: 4) { Text(clip.title).fontWeight(.semibold); Text(clip.subtitle).font(.caption).foregroundStyle(.secondary) }
                                Spacer()
                            }.padding(12).background(model.selectedClip == clip ? accent.opacity(0.08) : Color.white, in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(model.selectedClip == clip ? accent : Color.gray.opacity(0.2)))
                        }.buttonStyle(.plain)
                    }
                }
            }
            if let session = model.session, session.phase == .failed {
                banner(session.errorMessage ?? "Recognition failed.", color: .red)
            }
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("A future phone workflow").fontWeight(.semibold)
                    Text("Record or select a video → Gemini suggestions → your review.").font(.caption).foregroundStyle(.secondary)
                    Text("Camera capture, real video import and live inference are not implemented.").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if model.session?.phase == .failed { Button("Cancel") { model.cancelScan() } }
                Button(model.session?.phase == .failed ? "Retry demo recognition" : "Find items in demo clip") { model.startScan() }
                    .buttonStyle(.borderedProminent).controlSize(.large).disabled(!model.canSave)
            }
            principle("Review before saving", "Suggestions never enter inventory automatically.", icon: "checkmark.seal")
            principle("Rescan with confidence", "Unseen items stay saved. Similar objects need an explicit match.", icon: "arrow.triangle.2.circlepath")
        }.padding(24).background(.white, in: RoundedRectangle(cornerRadius: 20))
    }
    private var progress: some View {
        VStack(spacing: 24) {
            ProgressView()
            Text("Reading the demo observations…").font(.title2.bold())
            Text("Mock recognition is running locally. Nothing has been saved.").foregroundStyle(.secondary)
            Button("Cancel scan") { model.cancelScan() }
        }.frame(maxWidth: .infinity, minHeight: 440).background(.white, in: RoundedRectangle(cornerRadius: 20))
    }
    private func review(_ session: ScanSession) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            steps(active: 2)
            HStack {
                Text(session.clip.title).font(.headline)
                Spacer()
                Text("\(session.pendingCount) decisions remaining").font(.caption.weight(.semibold)).foregroundStyle(session.pendingCount == 0 ? accent : amber)
            }
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(session.proposals) { proposal in
                        ProposalCard(proposal: proposal, session: session, revise: model.revise)
                    }
                    if !session.baseline.isEmpty {
                        banner("\(session.retainedCount) existing items have no confirmed match and will be kept. Not seen does not mean removed.", color: accent)
                    }
                }.padding(1)
            }
            HStack {
                Button("Discard scan") { model.cancelScan() }
                Spacer()
                Text("Nothing saves until you approve.").font(.caption).foregroundStyle(.secondary)
                Button("Approve & save review") { model.approveScan() }
                    .buttonStyle(.borderedProminent).controlSize(.large).disabled(session.pendingCount > 0 || !model.canSave)
            }
        }
    }
    private var inventory: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your inventory").font(.title2.bold())
                    Text("Reviewed by you · Saved locally").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Add manually") { editingItem = InventoryItem(name: "") }.disabled(!model.canSave)
                Button { model.session = nil; model.selectedClip = .revisit; model.showIntake = true; model.notice = nil } label: {
                    Label("Revisit with a demo clip", systemImage: "video.badge.plus")
                }.buttonStyle(.borderedProminent).disabled(!model.canSave)
            }
            if model.items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "shippingbox").font(.system(size: 48))
                    Text("Your inventory starts with a review.").font(.title3.bold())
                    Text("Try Video intake or add an item manually.").foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, minHeight: 340)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(model.items.sorted { $0.name < $1.name }) { item in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: symbol(for: item.name)).font(.system(size: 28)).foregroundStyle(accent)
                                        .frame(width: 52, height: 52).background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                                    Spacer()
                                    Text("APPROVED").font(.system(size: 9, weight: .bold)).foregroundStyle(accent)
                                }
                                Text(item.name).font(.title3.bold())
                                Text(item.itemDescription.isEmpty ? "No description" : item.itemDescription).font(.callout).foregroundStyle(.secondary).lineLimit(2)
                                Label(item.location.isEmpty ? "No location recorded" : item.location, systemImage: "mappin.and.ellipse").font(.caption)
                                Text(item.lastSeenDate.map { "Last seen \($0.formatted(date: .abbreviated, time: .omitted))" } ?? "Not observed in a scan").font(.caption).foregroundStyle(.secondary)
                                Text(item.lastUsedDate.map { "Last used \($0.formatted(date: .abbreviated, time: .omitted))" } ?? "Last used not recorded").font(.caption).foregroundStyle(.secondary)
                                HStack {
                                    Button("Edit") { editingItem = item }
                                    Button("Used today") { model.markUsed(item) }
                                    Spacer()
                                    Button { pendingDeletion = item } label: { Image(systemName: "trash") }.accessibilityLabel("Delete \(item.name)")
                                }.buttonStyle(.borderless).disabled(!model.canSave)
                            }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(.white, in: RoundedRectangle(cornerRadius: 16))
                        }
                    }.padding(1)
                }
            }
        }
    }
    private func steps(active: Int) -> some View {
        HStack(spacing: 12) {
            ForEach(Array(["Select clip", "Review proposals", "Save inventory"].enumerated()), id: \.offset) { index, title in
                HStack(spacing: 8) {
                    Text("\(index + 1)").font(.caption.bold()).frame(width: 24, height: 24).background(index + 1 == active ? accent : accent.opacity(0.1), in: Circle()).foregroundStyle(index + 1 == active ? .white : accent)
                    Text(title).font(.caption.weight(index + 1 == active ? .bold : .regular))
                }
                if index < 2 { Rectangle().fill(accent.opacity(0.15)).frame(height: 1) }
            }
        }.padding(.bottom, 6)
    }
    private func principle(_ title: String, _ text: String, icon: String) -> some View {
        HStack(spacing: 12) { Image(systemName: icon).font(.title2).foregroundStyle(accent); VStack(alignment: .leading, spacing: 3) { Text(title).font(.callout.bold()); Text(text).font(.caption).foregroundStyle(.secondary) } }
    }
}

private struct ProposalCard: View {
    let proposal: ReviewProposal
    let session: ScanSession
    let revise: (ReviewProposal) -> Void
    private var ambiguous: Bool { !session.similarItems(to: proposal).isEmpty || session.hasDuplicateProposal(proposal) }
    private var decisionLabel: String {
        switch proposal.decision {
        case .pending: return "Needs decision"
        case .add: return "Add as new"
        case .update(let id): return "Match: \(session.baseline.first { $0.id == id }?.name ?? "Missing item")"
        case .ignore: return "Excluded"
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 7) {
                    Image(systemName: symbol(for: proposal.item.name)).font(.system(size: 24)).foregroundStyle(accent)
                    Text(proposal.observation.timestamp).font(.caption.monospacedDigit())
                }.frame(width: 56, height: 60).background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 6) {
                    field("Item name", value: \.name).font(.headline)
                    field("Description", value: \.itemDescription).font(.caption)
                    field("Location", value: \.location).font(.caption)
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 7) {
                    Text(decisionLabel).font(.caption.bold()).foregroundStyle(proposal.decision == .pending ? amber : accent)
                    Text("Mock score \(Int(proposal.observation.confidence * 100))%")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if ambiguous { Label("Possible repeat or existing item. Compare before adding.", systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(amber) }
            HStack(spacing: 10) {
                Button("Add as new") { change { $0.decision = .add } }
                Menu("Match existing…") {
                    ForEach(session.baseline) { item in
                        Button("\(item.name) · \(item.location) · \(item.id.uuidString.prefix(4))") { change { $0.decision = .update(item.id) } }
                    }
                }.disabled(session.baseline.isEmpty)
                Button("Exclude") { change { $0.decision = .ignore; $0.confirmedSeparate = false } }
                if proposal.decision != .pending { Button("Undo decision") { change { $0.decision = .pending; $0.confirmedSeparate = false } } }
                Spacer()
            }.buttonStyle(.bordered).controlSize(.small)
            if case .update(let id) = proposal.decision, let existing = session.baseline.first(where: { $0.id == id }) {
                Text("Update “\(existing.name)” at \(existing.location). Reviewed name, description and location replace those fields; usage history and value stay saved.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if proposal.decision == .add && ambiguous {
                Toggle("I checked: this is a separate physical object", isOn: Binding(get: { proposal.confirmedSeparate }, set: { value in change { $0.confirmedSeparate = value } })).font(.caption)
            }
        }.padding(15).background(.white, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(proposal.decision == .pending ? Color.gray.opacity(0.15) : accent.opacity(0.4)))
            .opacity(proposal.decision == .ignore ? 0.65 : 1)
    }
    @ViewBuilder private func field(_ title: String, value: WritableKeyPath<InventoryItem, String>) -> some View {
        TextField(title, text: Binding(get: { proposal.item[keyPath: value] }, set: { text in change { $0.item[keyPath: value] = text; $0.confirmedSeparate = false } })).textFieldStyle(.plain)
    }
    private func change(_ edit: (inout ReviewProposal) -> Void) { var next = proposal; edit(&next); revise(next) }
}

private struct ItemEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var item: InventoryItem
    @State private var error: String?
    let save: (InventoryItem) -> Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Item details").font(.title2.bold())
            Form {
                TextField("Name", text: $item.name)
                TextField("Description", text: $item.itemDescription)
                TextField("Location", text: $item.location)
                TextField("Estimated value (USD)", value: $item.estimatedValue, format: .number)
            }
            if let error { Text(error).foregroundStyle(.red) }
            HStack { Spacer(); Button("Cancel") { dismiss() }; Button("Save item") {
                if save(item) { dismiss() } else { error = "Could not save. Check the name and value, or retry. Your edits are still here." }
            }.buttonStyle(.borderedProminent) }
        }.padding(28).frame(width: 500)
    }
}

private func banner(_ text: String, color: Color) -> some View {
    Text(text).font(.callout).foregroundStyle(color).padding(12).frame(maxWidth: .infinity, alignment: .leading).background(color.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
}
private func symbol(for name: String) -> String {
    let value = name.lowercased()
    if value.contains("drill") { return "wrench.and.screwdriver" }
    if value.contains("lantern") { return "lightbulb" }
    if value.contains("helmet") { return "bicycle" }
    return "shippingbox"
}
private struct StorageIllustration: View {
    var body: some View {
        ZStack {
            Color(red: 0.92, green: 0.90, blue: 0.97)
            VStack(spacing: 18) {
                Text("A SPACE FULL OF POSSIBILITIES")
                    .font(.system(size: 9, weight: .bold, design: .monospaced)).tracking(1.2)
                HStack(alignment: .bottom, spacing: 20) {
                    VStack(spacing: 8) {
                        Image(systemName: "wrench.and.screwdriver.fill").font(.system(size: 40)).foregroundStyle(accent)
                        Image(systemName: "shippingbox.fill").font(.system(size: 64)).foregroundStyle(Color(red: 0.76, green: 0.48, blue: 0.27))
                    }
                    VStack(spacing: 13) {
                        Image(systemName: "lightbulb.fill").font(.system(size: 44)).foregroundStyle(Color(red: 0.89, green: 0.61, blue: 0.24))
                        Image(systemName: "archivebox.fill").font(.system(size: 52)).foregroundStyle(accent.opacity(0.65))
                    }
                }
                RoundedRectangle(cornerRadius: 3).fill(accent.opacity(0.14)).frame(width: 247, height: 5)
            }.padding(.bottom, 25)
        }
    }
}
