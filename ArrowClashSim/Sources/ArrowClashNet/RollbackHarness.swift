// RollbackHarness.swift
// Reusable offline harness for proving rollback correctness. It drives two
// RollbackSessions (one local to each player) across a SimulatedNetwork and
// compares their confirmed-frame states against a full-information reference
// replay that knows every input up front. If rollback is correct, both sessions
// agree with the reference at every confirmed frame.
//
// This is also what a local "rollback demo" in the app would call.

import ArrowClashSim

public enum RollbackHarness {

    public struct Scenario {
        public var frames: Int
        public var inputDelay: Int
        public var latency: Int
        public var jitter: Int
        public var lossPerThousand: UInt32
        public var seed: UInt64

        public init(
            frames: Int,
            inputDelay: Int = 2,
            latency: Int,
            jitter: Int = 0,
            lossPerThousand: UInt32 = 0,
            seed: UInt64
        ) {
            self.frames = frames
            self.inputDelay = inputDelay
            self.latency = latency
            self.jitter = jitter
            self.lossPerThousand = lossPerThousand
            self.seed = seed
        }
    }

    public struct Result {
        public var maxConfirmed: Int       // min of the two sessions' confirmedFrame
        public var framesCompared: Int     // number of frames checked against the reference
        public var matchedReference: Bool  // every compared frame matched on both sessions
        public var firstMismatch: Int?     // first frame that disagreed, if any
        public var rollbacksA: Int
        public var rollbacksB: Int
    }

    // Per-player raw input streams (indexed [player][callIndex]).
    public static func makeInputs(frames: Int, seed: UInt64) -> [[InputCommand]] {
        var s = seed
        func rnd() -> UInt32 {
            s = s &* 6364136223846793005 &+ 1442695040888963407
            return UInt32(truncatingIfNeeded: s >> 33)
        }
        var streams: [[InputCommand]] = [[], []]
        for _ in 0..<frames {
            for p in 0..<2 {
                let bits = UInt8(truncatingIfNeeded: rnd()) & 0b11111
                let aim = UInt8(truncatingIfNeeded: rnd())
                streams[p].append(InputCommand(buttons: InputCommand.Buttons(rawValue: bits), aim: aim))
            }
        }
        return streams
    }

    // Full-information replay. reference[f] is the start-of-frame state for frame
    // f, with the same inputDelay mapping the sessions use.
    public static func reference(
        raw: [[InputCommand]],
        frames: Int,
        inputDelay: Int,
        config: GameConfig,
        seed: UInt64
    ) -> [GameState] {
        let map = TileMap.defaultArena()
        var state = GameState.initial(config: config, seed: seed)
        var states: [GameState] = [state]
        for f in 0..<frames {
            let i0 = f - inputDelay >= 0 ? raw[0][f - inputDelay] : .neutral
            let i1 = f - inputDelay >= 0 ? raw[1][f - inputDelay] : .neutral
            Simulation.tick(state: &state, inputs: [i0, i1], map: map, config: config)
            states.append(state)
        }
        return states
    }

    public static func run(_ scenario: Scenario, config: GameConfig = .default) -> Result {
        let seed: UInt64 = 0xC0FFEE
        let raw = makeInputs(frames: scenario.frames, seed: scenario.seed ^ 0xABCD)

        let net = SimulatedNetwork(
            latency: scenario.latency,
            jitter: scenario.jitter,
            lossPerThousand: scenario.lossPerThousand,
            seed: scenario.seed
        )

        let a = RollbackSession(localPlayer: 0, transport: net.endpointA, config: config, seed: seed, inputDelay: scenario.inputDelay)
        let b = RollbackSession(localPlayer: 1, transport: net.endpointB, config: config, seed: seed, inputDelay: scenario.inputDelay)

        for f in 0..<scenario.frames {
            a.step(localInput: raw[0][f])
            b.step(localInput: raw[1][f])
            net.advance()
        }

        let ref = reference(raw: raw, frames: scenario.frames, inputDelay: scenario.inputDelay, config: config, seed: seed)

        let maxConfirmed = min(a.confirmedFrame, b.confirmedFrame)
        var matched = true
        var firstMismatch: Int? = nil
        var f = 0
        while f <= maxConfirmed {
            let h = stateHash(ref[f])
            if stateHash(a.stateAt(frame: f)) != h || stateHash(b.stateAt(frame: f)) != h {
                matched = false
                firstMismatch = f
                break
            }
            f += 1
        }

        return Result(
            maxConfirmed: maxConfirmed,
            framesCompared: maxConfirmed + 1,
            matchedReference: matched,
            firstMismatch: firstMismatch,
            rollbacksA: a.rollbackCount,
            rollbacksB: b.rollbackCount
        )
    }
}
