// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacMenubarAITracker",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "MacMenubarAITracker", targets: ["MacMenubarAITracker"])
    ],
    targets: [
        .executableTarget(name: "MacMenubarAITracker"),
        .testTarget(
            name: "MacMenubarAITrackerTests",
            dependencies: ["MacMenubarAITracker"]
        )
    ]
)
