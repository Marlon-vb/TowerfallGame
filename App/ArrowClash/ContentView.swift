// ContentView.swift
// Placeholder Phase 0 screen. It runs the sim for a fixed number of ticks and
// shows the resulting state hash, which both proves the app links the sim
// package and gives a quick on-device determinism sanity check. No game
// rendering here; that is Phase 1.

import SwiftUI
import ArrowClashSim

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("ArrowClash")
                .font(.largeTitle).bold()
            Text("Phase 0: deterministic sim core")
                .foregroundStyle(.secondary)
            Text("Sim self-check hash")
                .font(.caption)
            Text(Self.selfCheckHash())
                .font(.footnote.monospaced())
        }
        .padding()
    }

    // Runs a fixed neutral-input sequence and returns the final state hash.
    // The same code on any device must print the same value.
    static func selfCheckHash() -> String {
        let config = GameConfig.default
        let map = TileMap.defaultArena()
        var state = GameState.initial(config: config, seed: 1)
        for _ in 0..<120 {
            Simulation.tick(state: &state, inputs: [.neutral, .neutral], map: map, config: config)
        }
        return String(format: "%016llx", stateHash(state))
    }
}
