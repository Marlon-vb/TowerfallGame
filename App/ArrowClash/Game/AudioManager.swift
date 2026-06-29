// AudioManager.swift
// Preloads short sound effects as reusable SKActions and plays them on a node.
// Audio is render-only juice, gated by the Settings sound toggle. It never
// affects the simulation.

import SpriteKit

final class AudioManager {
    static let shared = AudioManager()

    private var actions: [String: SKAction] = [:]
    private let names = ["shoot", "jump", "dash", "hit", "ui"]
    private var loaded = false

    func preload() {
        guard !loaded else { return }
        loaded = true
        for name in names {
            actions[name] = SKAction.playSoundFileNamed("\(name).wav", waitForCompletion: false)
        }
    }

    func play(_ name: String, on node: SKNode) {
        guard Settings.soundEnabled, let action = actions[name] else { return }
        node.run(action)
    }
}
