// RollbackSession.swift
// GGPO-style rollback netcode for exactly two players.
//
// How it works each step():
//   1. The local input is assigned to a future frame (currentInput + inputDelay)
//      and a redundant window of recent local inputs is sent to the peer.
//   2. Incoming remote packets fill in remote inputs. If a newly confirmed input
//      for an already-simulated frame differs from the value we predicted there,
//      we mark that frame for rollback.
//   3. If a rollback is needed, restore the saved start-of-frame state at the
//      earliest such frame and re-simulate forward to the tip using the now
//      better-known inputs.
//   4. Simulate one brand-new frame at the tip, predicting the remote input if
//      it has not arrived yet.
//
// Prediction is "repeat the most recently received remote input." Crucially,
// correctness at confirmed frames does NOT depend on prediction quality: any
// confirmation that contradicts what we simulated triggers a rollback and
// re-simulation, so once a frame's whole history is confirmed its state equals
// what the peer (and a full-information replay) computes. Prediction quality
// only affects how often we roll back.
//
// Determinism note: this class is bookkeeping only and is never hashed or
// snapshotted, so its internal storage choices do not affect the deterministic
// game state. The GameState snapshots it saves and restores are what matter.
//
// Memory note: frame-indexed arrays grow without bound here for clarity. A
// production build caps them with a ring buffer sized to the maximum rollback
// distance (a frame older than confirmedFrame can never need rollback).

import ArrowClashSim

public final class RollbackSession: NetcodeSession {

    public let localPlayer: Int
    public var remotePlayer: Int { 1 - localPlayer }

    private let map: TileMap
    private let config: GameConfig
    private let inputDelay: Int
    private let redundancy: Int
    private let transport: InputTransport

    // Frame-indexed storage. states[f] is the start-of-frame state for frame f.
    private var states: [GameState]
    private var localInputs: [InputCommand]
    private var remoteInputs: [InputCommand]
    private var remoteConfirmed: [Bool]
    private var simulatedRemote: [InputCommand] // remote value actually used when frame f was simulated

    public private(set) var currentFrame: Int   // next frame to simulate
    private var localInputsAdded: Int           // number of local inputs supplied
    private var confirmedFrontier: Int          // smallest frame with unknown remote input
    private var newestConfirmedFrame: Int       // highest frame with a confirmed remote input

    public private(set) var rollbackCount: Int  // diagnostics

    public init(
        localPlayer: Int,
        transport: InputTransport,
        config: GameConfig,
        seed: UInt64,
        map: MapDefinition = Maps.default,
        inputDelay: Int = 2,
        redundancy: Int = 8
    ) {
        self.localPlayer = localPlayer
        self.transport = transport
        self.config = config
        self.inputDelay = inputDelay
        self.redundancy = redundancy

        self.map = map.tileMap()
        self.states = [GameState.initial(map: map, config: config, seed: seed)]
        self.localInputs = []
        self.remoteInputs = []
        self.remoteConfirmed = []
        self.simulatedRemote = []
        self.currentFrame = 0
        self.localInputsAdded = 0
        self.confirmedFrontier = 0
        self.newestConfirmedFrame = -1
        self.rollbackCount = 0
    }

    // MARK: - NetcodeSession

    public var confirmedFrame: Int {
        return min(confirmedFrontier, currentFrame)
    }

    public func stateAt(frame: Int) -> GameState {
        return states[frame]
    }

    public var latestState: GameState {
        return states[currentFrame]
    }

    public func step(localInput: InputCommand) {
        let resimTarget = currentFrame

        // 1. Assign and broadcast the local input (delayed by inputDelay frames).
        let assignFrame = localInputsAdded + inputDelay
        ensureCapacity(upTo: assignFrame)
        localInputs[assignFrame] = localInput
        localInputsAdded += 1
        sendLocalWindow(endFrame: assignFrame)

        // 2. Receive remote inputs; detect the earliest mispredicted frame.
        var rollbackTo = Int.max
        for packet in transport.poll() where packet.player == remotePlayer {
            var f = packet.startFrame
            for value in packet.inputs {
                if f >= 0 {
                    ensureCapacity(upTo: f)
                    if !remoteConfirmed[f] {
                        remoteInputs[f] = value
                        remoteConfirmed[f] = true
                        if f > newestConfirmedFrame { newestConfirmedFrame = f }
                        if f < currentFrame && simulatedRemote[f] != value {
                            if f < rollbackTo { rollbackTo = f }
                        }
                    }
                }
                f += 1
            }
        }
        advanceFrontier()

        // 3. Roll back and re-simulate to the tip if a prediction was wrong.
        if rollbackTo < currentFrame {
            rollbackCount += 1
            currentFrame = rollbackTo
            while currentFrame < resimTarget {
                simulateOneFrame()
            }
        }

        // 4. Simulate the new tip frame.
        simulateOneFrame()
    }

    // MARK: - Internals

    private func simulateOneFrame() {
        ensureCapacity(upTo: currentFrame)
        let localValue = localInputs[currentFrame]
        let remoteValue = remoteConfirmed[currentFrame] ? remoteInputs[currentFrame] : predictRemote()
        simulatedRemote[currentFrame] = remoteValue

        var next = states[currentFrame]
        Simulation.tick(state: &next, inputs: ordered(localValue, remoteValue), map: map, config: config)

        if states.count <= currentFrame + 1 {
            states.append(next)
        } else {
            states[currentFrame + 1] = next
        }
        currentFrame += 1
    }

    private func predictRemote() -> InputCommand {
        return newestConfirmedFrame >= 0 ? remoteInputs[newestConfirmedFrame] : .neutral
    }

    private func ordered(_ local: InputCommand, _ remote: InputCommand) -> [InputCommand] {
        var arr = [InputCommand](repeating: .neutral, count: 2)
        arr[localPlayer] = local
        arr[remotePlayer] = remote
        return arr
    }

    private func advanceFrontier() {
        while confirmedFrontier < remoteConfirmed.count && remoteConfirmed[confirmedFrontier] {
            confirmedFrontier += 1
        }
    }

    private func sendLocalWindow(endFrame: Int) {
        let start = max(0, endFrame - redundancy + 1)
        var window: [InputCommand] = []
        window.reserveCapacity(endFrame - start + 1)
        var f = start
        while f <= endFrame {
            window.append(localInputs[f])
            f += 1
        }
        transport.send(InputPacket(player: localPlayer, startFrame: start, inputs: window))
    }

    private func ensureCapacity(upTo frame: Int) {
        if frame < localInputs.count { return }
        let needed = frame + 1
        while localInputs.count < needed {
            localInputs.append(.neutral)
            remoteInputs.append(.neutral)
            remoteConfirmed.append(false)
            simulatedRemote.append(.neutral)
        }
    }
}
