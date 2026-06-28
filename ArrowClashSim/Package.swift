// swift-tools-version:5.9
import PackageDescription

// ArrowClashSim is the deterministic game simulation module.
// It MUST NOT import UIKit or SpriteKit. The iOS app target depends on
// this package and renders the state the sim produces.
let package = Package(
    name: "ArrowClashSim",
    products: [
        .library(name: "ArrowClashSim", targets: ["ArrowClashSim"]),
    ],
    targets: [
        .target(
            name: "ArrowClashSim"
        ),
        .testTarget(
            name: "ArrowClashSimTests",
            dependencies: ["ArrowClashSim"]
        ),
    ]
)
