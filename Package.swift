// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StowSight",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "StowSight", targets: ["StorageTrackerApp"]),
        .executable(name: "StorageTracker", targets: ["StorageTrackerApp"]) // Legacy launch compatibility.
    ],
    targets: [
        .target(name: "InventoryCore"),
        .executableTarget(name: "StorageTrackerApp", dependencies: ["InventoryCore"]),
        .executableTarget(name: "InventoryChecks", dependencies: ["InventoryCore"], path: "Tests/InventoryChecks")
    ]
)
