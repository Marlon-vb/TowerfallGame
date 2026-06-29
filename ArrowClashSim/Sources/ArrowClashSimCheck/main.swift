// main.swift
// XCTest-free verification of the Phase 0 acceptance gate. Runs the same
// determinism and movement checks as the XCTest suite, prints a pass/fail line
// per check, and exits non-zero if anything fails.
//
// Run with only the Command Line Tools installed:
//   cd ArrowClashSim && swift run ArrowClashSimCheck
//
// The XCTest target (ArrowClashSimTests) remains the canonical suite for Xcode.

import Foundation
import ArrowClashSim

// MARK: - Tiny check harness

var failures = 0
func check(_ condition: Bool, _ name: String) {
    if condition {
        print("  ok   - \(name)")
    } else {
        print("  FAIL - \(name)")
        failures += 1
    }
}

// MARK: - Shared helpers

// Test-only LCG driver to generate a reproducible, varied input stream. Not
// part of the game state.
func makeInputs(count: Int, seed: UInt64) -> [[InputCommand]] {
    var s = seed
    func rnd() -> UInt32 {
        s = s &* 6364136223846793005 &+ 1442695040888963407
        return UInt32(truncatingIfNeeded: s >> 33)
    }
    var sequence: [[InputCommand]] = []
    sequence.reserveCapacity(count)
    for _ in 0..<count {
        var perPlayer: [InputCommand] = []
        for _ in 0..<2 {
            let bits = UInt8(truncatingIfNeeded: rnd()) & 0b11111
            let aim = UInt8(truncatingIfNeeded: rnd())
            perPlayer.append(InputCommand(buttons: InputCommand.Buttons(rawValue: bits), aim: aim))
        }
        sequence.append(perPlayer)
    }
    return sequence
}

func emptyMap() -> TileMap {
    return TileMap(cols: 20, rows: 12, solid: [Bool](repeating: false, count: 20 * 12))
}

let neutral: [InputCommand] = [.neutral, .neutral]

// MARK: - Determinism checks

print("Determinism")

do {
    // Identical replay -> identical per-tick state hash.
    let map = TileMap.defaultArena()
    let config = GameConfig.default
    let inputs = makeInputs(count: 1200, seed: 0xA11CE)

    var a = GameState.initial(config: config, seed: 1)
    var b = GameState.initial(config: config, seed: 1)
    var diverged = false
    for t in 0..<inputs.count {
        Simulation.tick(state: &a, inputs: inputs[t], map: map, config: config)
        Simulation.tick(state: &b, inputs: inputs[t], map: map, config: config)
        if stateHash(a) != stateHash(b) { diverged = true; break }
    }
    check(!diverged && a == b, "identical replay produces identical state (1200 ticks)")
}

do {
    // Snapshot by value copy stays in sync.
    let map = TileMap.defaultArena()
    let config = GameConfig.default
    let inputs = makeInputs(count: 600, seed: 0xBEEF)

    var live = GameState.initial(config: config, seed: 7)
    for t in 0..<300 {
        Simulation.tick(state: &live, inputs: inputs[t], map: map, config: config)
    }
    var restored = live // snapshot
    for t in 300..<600 {
        Simulation.tick(state: &live, inputs: inputs[t], map: map, config: config)
        Simulation.tick(state: &restored, inputs: inputs[t], map: map, config: config)
    }
    check(stateHash(live) == stateHash(restored) && live == restored,
          "snapshot-by-copy stays in sync after restore")
}

do {
    // Different inputs must diverge (proves the hash is sensitive).
    let map = TileMap.defaultArena()
    let config = GameConfig.default
    let inputsA = makeInputs(count: 300, seed: 1)
    let inputsB = makeInputs(count: 300, seed: 2)

    var a = GameState.initial(config: config, seed: 1)
    var b = GameState.initial(config: config, seed: 1)
    for t in 0..<300 {
        Simulation.tick(state: &a, inputs: inputsA[t], map: map, config: config)
        Simulation.tick(state: &b, inputs: inputsB[t], map: map, config: config)
    }
    check(stateHash(a) != stateHash(b), "different inputs produce different state")
}

// MARK: - Movement checks

print("Movement")

do {
    // Gravity + landing on the central platform at the spawn Y.
    let map = TileMap.defaultArena()
    let config = GameConfig.default
    var state = GameState.initial(config: config, seed: 1)
    state.players[0].pos.y = Fixed(40)
    for _ in 0..<180 {
        Simulation.tick(state: &state, inputs: neutral, map: map, config: config)
    }
    check(state.players[0].onGround
          && state.players[0].pos.y == Fixed(config.spawnY)
          && state.players[0].vel.y == .zero,
          "gravity drops player and lands at rest on platform")
}

do {
    // Run speed clamps to the max in open space.
    let map = emptyMap()
    let config = GameConfig.default
    var state = GameState.initial(config: config, seed: 1)
    let right = InputCommand(buttons: [.right])
    var overshot = false
    for _ in 0..<60 {
        Simulation.tick(state: &state, inputs: [right, .neutral], map: map, config: config)
        if state.players[0].vel.x.raw > config.runMaxSpeed.raw { overshot = true }
    }
    check(!overshot
          && state.players[0].vel.x == config.runMaxSpeed
          && state.players[0].facing == 1,
          "horizontal run velocity clamps to max")
}

do {
    // Dash sets dash velocity, then cooldown blocks an immediate re-dash.
    let map = TileMap.defaultArena()
    let config = GameConfig.default
    var state = GameState.initial(config: config, seed: 1)
    let dash = InputCommand(buttons: [.dash])

    Simulation.tick(state: &state, inputs: [dash, .neutral], map: map, config: config)
    let startedDash = state.players[0].dashActiveTimer == config.dashDurationTicks
        && state.players[0].vel.x == config.dashSpeed

    var guardCount = 0
    while state.players[0].dashActiveTimer > 0 && guardCount < 100 {
        Simulation.tick(state: &state, inputs: neutral, map: map, config: config)
        guardCount += 1
    }
    let onCooldown = state.players[0].dashCooldownTimer > 0

    Simulation.tick(state: &state, inputs: [dash, .neutral], map: map, config: config)
    let reDashBlocked = state.players[0].dashActiveTimer == 0

    check(startedDash && onCooldown && reDashBlocked, "dash respects cooldown")
}

do {
    // Jump from ground lifts the player (negative-y velocity, leaves ground).
    let map = TileMap.defaultArena()
    let config = GameConfig.default
    var state = GameState.initial(config: config, seed: 1)
    for _ in 0..<10 {
        Simulation.tick(state: &state, inputs: neutral, map: map, config: config)
    }
    let wasGrounded = state.players[0].onGround
    let jump = InputCommand(buttons: [.jump])
    Simulation.tick(state: &state, inputs: [jump, .neutral], map: map, config: config)
    check(wasGrounded && !state.players[0].onGround && state.players[0].vel.y.raw < 0,
          "jump from ground lifts the player")
}

// MARK: - Summary

print("")
if failures == 0 {
    print("ALL CHECKS PASSED")
    exit(0)
} else {
    print("\(failures) CHECK(S) FAILED")
    exit(1)
}
