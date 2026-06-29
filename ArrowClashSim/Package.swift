// swift-tools-version:5.9
import PackageDescription

// ArrowClashSim is the deterministic game simulation module.
// It MUST NOT import UIKit or SpriteKit. The iOS app target depends on
// this package and renders the state the sim produces.
let package = Package(
    name: "ArrowClashSim",
    products: [
        .library(name: "ArrowClashSim", targets: ["ArrowClashSim"]),
        // Runnable check that needs no XCTest, so determinism can be verified
        // with only the Command Line Tools installed:  swift run ArrowClashSimCheck
        .executable(name: "ArrowClashSimCheck", targets: ["ArrowClashSimCheck"]),
    ],
    targets: [
        .target(
            name: "ArrowClashSim"
        ),
        .executableTarget(
            name: "ArrowClashSimCheck",
            dependencies: ["ArrowClashSim"]
        ),
        .testTarget(
            name: "ArrowClashSimTests",
            dependencies: ["ArrowClashSim"]
        ),
    ]
)
