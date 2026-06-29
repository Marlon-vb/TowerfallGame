// swift-tools-version:5.9
import PackageDescription

// ArrowClashSim is the deterministic game simulation module.
// It MUST NOT import UIKit or SpriteKit. The iOS app target depends on
// this package and renders the state the sim produces.
//
// ArrowClashNet is the netcode layer (rollback for v1). It depends on the sim
// but is also free of UIKit/SpriteKit, and sits behind protocols so the
// rollback implementation can be swapped (e.g. authoritative-tick) and the
// transport can be swapped (e.g. Nakama) without touching the sim.
let package = Package(
    name: "ArrowClashSim",
    products: [
        .library(name: "ArrowClashSim", targets: ["ArrowClashSim"]),
        .library(name: "ArrowClashNet", targets: ["ArrowClashNet"]),
        // Runnable check that needs no XCTest, so the sim + rollback can be
        // verified with only the Command Line Tools:  swift run ArrowClashSimCheck
        .executable(name: "ArrowClashSimCheck", targets: ["ArrowClashSimCheck"]),
    ],
    targets: [
        .target(
            name: "ArrowClashSim"
        ),
        .target(
            name: "ArrowClashNet",
            dependencies: ["ArrowClashSim"]
        ),
        .executableTarget(
            name: "ArrowClashSimCheck",
            dependencies: ["ArrowClashSim", "ArrowClashNet"]
        ),
        .testTarget(
            name: "ArrowClashSimTests",
            dependencies: ["ArrowClashSim"]
        ),
        .testTarget(
            name: "ArrowClashNetTests",
            dependencies: ["ArrowClashNet", "ArrowClashSim"]
        ),
    ]
)
