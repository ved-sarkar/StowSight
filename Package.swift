// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StorageTracker",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "StorageTracker", targets: ["StorageTrackerApp"])],
    targets: [
        .target(name: "InventoryCore"),
        .executableTarget(name: "StorageTrackerApp", dependencies: ["InventoryCore"]),
        .executableTarget(name: "InventoryChecks", dependencies: ["InventoryCore"], path: "Tests/InventoryChecks")
    ]
)
