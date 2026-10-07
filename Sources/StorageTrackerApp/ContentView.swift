import SwiftUI
import InventoryCore

struct ContentView: View {
    @ObservedObject var model: InventoryViewModel
    @State private var editingItem: InventoryItem?
    @State private var pendingDeletion: InventoryItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Storage Inventory").font(.largeTitle.bold())
                    Text("Know what you have, where it is, and when you last used it.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button { editingItem = InventoryItem(name: "") } label: {
                    Label("Add item", systemImage: "plus")
                }
                .disabled(!model.canSave)
                .keyboardShortcut("n", modifiers: .command)
            }
            .padding()

            if let error = model.errorMessage {
                Text(error).foregroundStyle(.red).padding(.horizontal).padding(.bottom)
                    .accessibilityLabel("Error: \(error)")
            }

            if model.items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "shippingbox").font(.system(size: 40))
                    Text(model.canSave ? "Your inventory starts here" : "Inventory unavailable")
                        .font(.title2)
                    Text(model.canSave ? "Add a belonging and give it a place." : "Check the local inventory file, then reopen the app.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(model.items.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(item.name).font(.headline)
                            Spacer()
                            Button("Edit") { editingItem = item }
                            Button("Used today") { model.markUsed(item) }
                            Button(role: .destructive) { pendingDeletion = item } label: {
                                Image(systemName: "trash")
                            }
                            .accessibilityLabel("Delete \(item.name)")
                        }
                        if !item.itemDescription.isEmpty { Text(item.itemDescription) }
                        HStack {
                            if !item.location.isEmpty {
                                Label(item.location, systemImage: "mappin.and.ellipse")
                            }
                            if item.estimatedValue > 0 {
                                Text(item.estimatedValue, format: .currency(code: "USD"))
                            }
                            Spacer()
                            Text("Last used: \(item.lastUsedDate.formatted(date: .abbreviated, time: .omitted))")
                        }
                        .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                    .buttonStyle(.borderless)
                }
            }
            Text("\(model.items.count) items · Saved on this Mac")
                .font(.caption).foregroundStyle(.secondary).padding()
        }
        .sheet(item: $editingItem) { item in
            ItemEditor(item: item, save: model.save)
        }
        .alert("Delete this item?", isPresented: Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        )) {
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
            Button("Delete", role: .destructive) {
                if let item = pendingDeletion { model.delete(item) }
                pendingDeletion = nil
            }
        } message: {
            Text("This removes the item from your local inventory.")
        }
    }
}

private struct ItemEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var item: InventoryItem
    @State private var valueText: String
    @State private var error: String?
    let save: (InventoryItem) -> Bool

    init(item: InventoryItem, save: @escaping (InventoryItem) -> Bool) {
        _item = State(initialValue: item)
        _valueText = State(initialValue: item.estimatedValue == 0 ? "" : String(item.estimatedValue))
        self.save = save
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Item details").font(.title2.bold())
            Form {
                TextField("Name", text: $item.name)
                TextField("Description", text: $item.itemDescription)
                TextField("Location", text: $item.location)
                TextField("Estimated value (USD, e.g. 12.50)", text: $valueText)
                DatePicker("Last used", selection: $item.lastUsedDate, displayedComponents: .date)
            }
            if let error { Text(error).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") {
                    let rawValue = valueText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard let value = rawValue.isEmpty ? 0 : Double(rawValue), value.isFinite, value >= 0 else {
                        error = "Enter a nonnegative amount using a decimal point, or leave it blank."
                        return
                    }
                    guard !item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        error = "Enter an item name."
                        return
                    }
                    item.estimatedValue = value
                    if save(item) { dismiss() }
                    else { error = "Could not save the item. Your changes are still here so you can retry." }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24).frame(width: 480)
    }
}
