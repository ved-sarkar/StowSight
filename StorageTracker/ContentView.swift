import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel: InventoryViewModel
    @State private var showingCamera = false
    @State private var showingError = false
    
    init() {
        let context = PersistenceController.shared.container.viewContext
        _viewModel = StateObject(wrappedValue: InventoryViewModel(context: context))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                List {
                    ForEach(viewModel.items) { item in
                        ItemRow(item: item, onReset: {
                            viewModel.resetItemDate(item)
                        })
                    }
                    .onDelete { indexSet in
                        indexSet.forEach { index in
                            viewModel.deleteItem(viewModel.items[index])
                        }
                    }
                }
                
                if viewModel.isLoading {
                    ProgressView("Processing video...")
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 10)
                }
            }
            .navigationTitle("Storage Inventory")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingCamera = true
                    }) {
                        Image(systemName: "video.fill")
                    }
                }
            }
            .sheet(isPresented: $showingCamera) {
                CameraView { videoURL in
                    Task {
                        await viewModel.processVideo(url: videoURL)
                    }
                }
            }
            .alert("Error", isPresented: $showingError, presenting: viewModel.error) { _ in
                Button("OK", role: .cancel) {}
            } message: { error in
                Text(error)
            }
        }
    }
}

struct ItemRow: View {
    let item: InventoryItem
    let onReset: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.name)
                    .font(.headline)
                Spacer()
                Button(action: onReset) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.blue)
                }
            }
            
            if let description = item.itemDescription {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                if item.estimatedValue > 0 {
                    Text("Value: $\(String(format: "%.2f", item.estimatedValue))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("Last used: \(item.lastUsedDate, style: .relative) ago")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let location = item.location {
                Text("Location: \(location)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
} 