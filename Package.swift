// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FrameCalculator",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "FrameCalculator",
            targets: ["FrameCalculator"]
        )
    ],
    targets: [
        .target(
            name: "FrameCalculator",
            path: "FrameCalculator",
            exclude: ["App", "Views", "ViewModels"]  // Exclude UI components from library
        ),
        .testTarget(
            name: "FrameCalculatorTests",
            dependencies: ["FrameCalculator"],
            path: "FrameCalculatorTests"
        )
    ]
)
