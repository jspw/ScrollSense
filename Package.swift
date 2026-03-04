// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ScrollSense",
    platforms: [
        .macOS(.v12)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.0.0")
    ],
    targets: [
        // Library target containing all core logic (testable)
        .target(
            name: "ScrollSenseCore",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/ScrollSense"
        ),
        // Executable target (thin wrapper)
        .executableTarget(
            name: "scrollSense",
            dependencies: ["ScrollSenseCore"],
            path: "Sources/ScrollSenseApp"
        ),
        // Test target
        .testTarget(
            name: "ScrollSenseTests",
            dependencies: ["ScrollSenseCore"]
        ),
    ]
)
