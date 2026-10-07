// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StorageTracker",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "StorageTracker",
            targets: ["StorageTracker"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "StorageTracker",
            dependencies: [
                .product(name: "Logging", package: "swift-log")
            ],
            path: "Sources"
        )
    ]
) 