// swift-tools-version: 5.9
import PackageDescription

// This Package.swift is for running tests via `swift test`.
// For building the app, use the Xcode project (Timecoder.xcodeproj).

let package = Package(
    name: "Timecoder",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "TimecoderCore",
            targets: ["TimecoderCore"]
        )
    ],
    targets: [
        // Core library (Models only - for testing)
        .target(
            name: "TimecoderCore",
            path: "Timecoder/Models"
        ),
        // Tests
        .testTarget(
            name: "TimecoderTests",
            dependencies: ["TimecoderCore"],
            path: "TimecoderTests"
        )
    ]
)
