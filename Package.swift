// swift-tools-version: 5.9
import PackageDescription

// This Package.swift is for running tests via `swift test`.
// For building the app, use the Xcode project (FrameCalculator.xcodeproj).

let package = Package(
    name: "FrameCalculator",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "FrameCalculatorCore",
            targets: ["FrameCalculatorCore"]
        )
    ],
    targets: [
        // Core library (Models only - for testing)
        .target(
            name: "FrameCalculatorCore",
            path: "FrameCalculator/Models"
        ),
        // Tests
        .testTarget(
            name: "FrameCalculatorTests",
            dependencies: ["FrameCalculatorCore"],
            path: "FrameCalculatorTests"
        )
    ]
)
