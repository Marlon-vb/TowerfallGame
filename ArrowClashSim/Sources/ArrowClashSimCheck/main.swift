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
import ArrowClashNet

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
    state.phase = .playing
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
    state.phase = .playing
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
    state.phase = .playing
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
    state.phase = .playing
    for _ in 0..<10 {
        Simulation.tick(state: &state, inputs: neutral, map: map, config: config)
    }
    let wasGrounded = state.players[0].onGround
    let jump = InputCommand(buttons: [.jump])
    Simulation.tick(state: &state, inputs: [jump, .neutral], map: map, config: config)
    check(wasGrounded && !state.players[0].onGround && state.players[0].vel.y.raw < 0,
          "jump from ground lifts the player")
}

// MARK: - Combat (arrows)

print("Combat")

do {
    // Shooting consumes a quiver arrow and spawns one active projectile.
    let map = TileMap.defaultArena()
    let config = GameConfig.default
    var state = GameState.initial(config: config, seed: 1)
    state.phase = .playing

    // Aim right (dir 0). Shoot on press edge.
    let shoot = InputCommand(buttons: [.shoot], aim: 0)
    Simulation.tick(state: &state, inputs: [shoot, .neutral], map: map, config: config)

    let activeCount = state.arrows.filter { $0.active }.count
    let arrow = state.arrows.first { $0.active }
    check(state.players[0].arrows == config.startingArrows - 1
          && activeCount == 1
          && arrow?.owner == 0
          && arrow?.vel.x == config.arrowSpeed,
          "shoot consumes a quiver arrow and spawns a projectile")
}

do {
    // A player overlapping a stuck arrow reclaims it when the quiver is not full.
    let map = TileMap.defaultArena()
    let config = GameConfig.default
    var state = GameState.initial(config: config, seed: 1)
    state.phase = .playing

    // Put a stuck arrow inside player 0's AABB and open a quiver slot.
    let center = FixedVec(
        x: state.players[0].pos.x + config.playerWidth / Fixed(2),
        y: state.players[0].pos.y + config.playerHeight / Fixed(2)
    )
    state.arrows[0] = ArrowState(pos: center, active: true, stuck: true, owner: 1, dir: 0)
    state.players[0].arrows = config.startingArrows - 1

    Simulation.tick(state: &state, inputs: neutral, map: map, config: config)

    check(state.players[0].arrows == config.startingArrows
          && state.arrows.filter { $0.active }.count == 0,
          "player reclaims a stuck arrow walked over")
}

// MARK: - Match flow

print("Match flow")

do {
    // Countdown freezes input, then transitions to playing.
    let map = TileMap.defaultArena()
    let config = GameConfig.default
    var state = GameState.initial(config: config, seed: 1)
    let right = InputCommand(buttons: [.right])
    let startX = state.players[0].pos.x
    for _ in 0..<Int(config.countdownTicks) {
        Simulation.tick(state: &state, inputs: [right, .neutral], map: map, config: config)
    }
    check(state.phase == .playing && state.players[0].pos.x == startX,
          "countdown freezes input then starts the round")
}

do {
    // An arrow kill scores and ends the round; after roundOver a new round
    // starts with players respawned and scores carried over.
    let map = TileMap.defaultArena()
    let config = GameConfig.default
    var state = GameState.initial(config: config, seed: 1)
    state.phase = .playing
    let center = FixedVec(
        x: state.players[1].pos.x + config.playerWidth / Fixed(2),
        y: state.players[1].pos.y + config.playerHeight / Fixed(2)
    )
    state.arrows[0] = ArrowState(pos: center, active: true, stuck: false, owner: 0, dir: 0)

    Simulation.tick(state: &state, inputs: [.neutral, .neutral], map: map, config: config)
    let scoredAndEnded = !state.players[1].alive && state.scores[0] == 1 && state.phase == .roundOver

    for _ in 0..<Int(config.roundOverTicks) {
        Simulation.tick(state: &state, inputs: [.neutral, .neutral], map: map, config: config)
    }
    let reset = state.phase == .countdown && state.round == 1 && state.scores[0] == 1
        && state.players[1].alive && state.arrows.filter { $0.active }.count == 0

    check(scoredAndEnded && reset, "arrow kill scores, ends round, then resets")
}

do {
    // Reaching roundsToWin ends the match.
    let map = TileMap.defaultArena()
    let config = GameConfig.default
    var state = GameState.initial(config: config, seed: 1)
    state.phase = .playing
    state.scores[0] = config.roundsToWin - 1
    let center = FixedVec(
        x: state.players[1].pos.x + config.playerWidth / Fixed(2),
        y: state.players[1].pos.y + config.playerHeight / Fixed(2)
    )
    state.arrows[0] = ArrowState(pos: center, active: true, stuck: false, owner: 0, dir: 0)
    Simulation.tick(state: &state, inputs: [.neutral, .neutral], map: map, config: config)
    for _ in 0..<Int(config.roundOverTicks) {
        Simulation.tick(state: &state, inputs: [.neutral, .neutral], map: map, config: config)
    }
    check(state.phase == .matchOver && state.winner == 0,
          "match ends at roundsToWin with correct winner")
}

// MARK: - Rollback netcode

print("Rollback")

do {
    // No latency, no loss: both sessions track the reference closely.
    let r = RollbackHarness.run(.init(frames: 600, latency: 0, seed: 1))
    check(r.matchedReference && r.maxConfirmed >= 600 - 10,
          "no-latency sessions match reference at every confirmed frame")
}

do {
    // Latency well above input delay: rollbacks must occur, and confirmed
    // frames must still match the reference exactly.
    let r = RollbackHarness.run(.init(frames: 600, inputDelay: 2, latency: 6, seed: 2))
    check(r.matchedReference
          && r.maxConfirmed >= 600 - 16
          && r.rollbacksA > 0 && r.rollbacksB > 0,
          "latency causes rollbacks but confirmed frames still match (rollbacks A=\(r.rollbacksA) B=\(r.rollbacksB))")
}

do {
    // Latency + jitter + 20% packet loss: redundancy recovers losses; confirmed
    // frames still match the reference.
    let r = RollbackHarness.run(.init(frames: 800, inputDelay: 2, latency: 5, jitter: 3, lossPerThousand: 200, seed: 3))
    check(r.matchedReference && r.maxConfirmed >= 800 - 60,
          "lossy/jittery link still matches reference at confirmed frames (confirmed=\(r.maxConfirmed)/800)")
}

do {
    // Fuzz: many seeds and conditions, all must match the reference.
    var allMatched = true
    var worstConfirmed = Int.max
    for seed in UInt64(1)...UInt64(40) {
        let latency = Int(seed % 8)
        let loss = UInt32((seed * 37) % 250)
        let r = RollbackHarness.run(.init(frames: 400, inputDelay: 2, latency: latency, jitter: Int(seed % 4), lossPerThousand: loss, seed: seed))
        if !r.matchedReference { allMatched = false; break }
        worstConfirmed = min(worstConfirmed, r.maxConfirmed)
    }
    check(allMatched && worstConfirmed >= 400 - 80,
          "fuzz: 40 randomized scenarios all match reference (worst confirmed=\(worstConfirmed)/400)")
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
