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
//      it has not arrived yet - UNLESS we are already too far ahead of confirmed
//      (the prediction barrier), in which case we stall this frame instead of
//      predicting unboundedly.
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
// Hardening (Phase 10.1):
//   - Memory is bounded by a sliding window: frames older than the confirmed
//     frontier (minus a small safety margin) can never be needed again and are
//     evicted. `baseFrame` is the frame of storage index 0; `oldestRetainedFrame`
//     exposes it. A frame is addressable in [oldestRetainedFrame, currentFrame].
//   - A prediction barrier (`maxPredictionFrames`) stops the tip from running
//     unboundedly ahead of confirmed when the peer goes quiet; this also keeps
//     the rollback window (and memory) bounded.
//   - Connection health: `framesSinceRemoteInput` / `connectionState` let the app
//     show "unstable" and declare a forfeit on a real disconnect.
//   - Desync detection: `localChecksum()` reports a confirmed-frame state hash;
//     `ingestPeerChecksum(...)` compares the peer's against ours and trips
//     `desyncDetected` if a confirmed frame disagrees (the safety net behind the
//     determinism guarantee).

import ArrowClashSim

public final class RollbackSession: NetcodeSession {

    /// Coarse health of the link to the peer, derived from how long we have gone
    /// without a fresh remote input.
    public enum ConnectionState: Equatable {
        case healthy       // recent remote input received
        case unstable      // gone quiet long enough to predict/stall, not yet dead
        case disconnected  // quiet past the timeout - treat as gone (forfeit)
    }

    /// A confirmed-frame state hash for cross-peer desync detection.
    public struct ChecksumReport: Equatable {
        public let frame: Int
        public let hash: UInt64
        public init(frame: Int, hash: UInt64) {
            self.frame = frame
            self.hash = hash
        }
    }

    public let localPlayer: Int
    public var remotePlayer: Int { 1 - localPlayer }

    private let map: TileMap
    private let config: GameConfig
    private let inputDelay: Int
    private let redundancy: Int
    private let transport: InputTransport

    // Tuning for the hardening behaviours.
    private let maxPredictionFrames: Int    // tip may lead confirmed by at most this
    private let retainBehindConfirmed: Int  // frames kept behind the frontier as margin
    private let unstableTimeoutFrames: Int  // no remote input for this long -> unstable
    private let disconnectTimeoutFrames: Int// ...this long -> disconnected

    // Frame-indexed storage, offset by baseFrame: index i holds frame baseFrame+i.
    // states[i] is the start-of-frame state for frame baseFrame+i.
    private var states: [GameState]
    private var localInputs: [InputCommand]
    private var remoteInputs: [InputCommand]
    private var remoteConfirmed: [Bool]
    private var simulatedRemote: [InputCommand] // remote value actually used when a frame was simulated
    private var baseFrame: Int                  // frame index of storage slot 0

    public private(set) var currentFrame: Int   // next frame to simulate
    private var localInputsAdded: Int           // number of local inputs supplied
    private var confirmedFrontier: Int          // smallest frame with unknown remote input
    private var newestConfirmedFrame: Int       // highest frame with a confirmed remote input

    public private(set) var rollbackCount: Int  // diagnostics
    /// True when the most recent step() refused to advance the tip because the
    /// prediction barrier was reached (peer too far behind). The app should hold
    /// the last rendered state / show a "waiting" indicator while this is true.
    public private(set) var isStalled: Bool
    /// Frames elapsed since we last received a fresh remote input.
    public private(set) var framesSinceRemoteInput: Int
    /// True once a confirmed frame's hash disagreed with the peer's.
    public private(set) var desyncDetected: Bool
    /// The first confirmed frame found to disagree, if any.
    public private(set) var desyncFrame: Int?
    // Peer checksums awaiting a frame we have not confirmed yet, keyed by frame.
    private var pendingPeerChecksums: [Int: UInt64]

    public init(
        localPlayer: Int,
        transport: InputTransport,
        config: GameConfig,
        seed: UInt64,
        map: MapDefinition = Maps.default,
        inputDelay: Int = 2,
        redundancy: Int = 8,
        maxPredictionFrames: Int = 30,
        retainBehindConfirmed: Int = 8,
        unstableTimeoutFrames: Int = 30,
        disconnectTimeoutFrames: Int = 600
    ) {
        self.localPlayer = localPlayer
        self.transport = transport
        self.config = config
        self.inputDelay = inputDelay
        self.redundancy = redundancy
        self.maxPredictionFrames = max(1, maxPredictionFrames)
        self.retainBehindConfirmed = max(0, retainBehindConfirmed)
        self.unstableTimeoutFrames = unstableTimeoutFrames
        self.disconnectTimeoutFrames = disconnectTimeoutFrames

        self.map = map.tileMap()
        self.states = [GameState.initial(map: map, config: config, seed: seed)]
        self.localInputs = []
        self.remoteInputs = []
        self.remoteConfirmed = []
        self.simulatedRemote = []
        self.baseFrame = 0
        self.currentFrame = 0
        self.localInputsAdded = 0
        self.confirmedFrontier = 0
        self.newestConfirmedFrame = -1
        self.rollbackCount = 0
        self.isStalled = false
        self.framesSinceRemoteInput = 0
        self.desyncDetected = false
        self.desyncFrame = nil
        self.pendingPeerChecksums = [:]
    }

    // MARK: - NetcodeSession

    public var confirmedFrame: Int {
        return min(confirmedFrontier, currentFrame)
    }

    public func stateAt(frame: Int) -> GameState {
        precondition(frame >= baseFrame && frame <= currentFrame,
                     "frame \(frame) outside retained window [\(baseFrame), \(currentFrame)]")
        return states[frame - baseFrame]
    }

    public var latestState: GameState {
        return states[currentFrame - baseFrame]
    }

    public func step(localInput: InputCommand) {
        let resimTarget = currentFrame

        // 1. Assign and broadcast the local input (delayed by inputDelay frames).
        let assignFrame = localInputsAdded + inputDelay
        ensureCapacity(upTo: assignFrame)
        localInputs[idx(assignFrame)] = localInput
        localInputsAdded += 1
        sendLocalWindow(endFrame: assignFrame)

        // 2. Receive remote inputs; detect the earliest mispredicted frame.
        var rollbackTo = Int.max
        var gotNewRemote = false
        for packet in transport.poll() where packet.player == remotePlayer {
            var f = packet.startFrame
            for value in packet.inputs {
                if f >= baseFrame {  // frames below baseFrame are already confirmed + evicted
                    ensureCapacity(upTo: f)
                    if !remoteConfirmed[idx(f)] {
                        remoteInputs[idx(f)] = value
                        remoteConfirmed[idx(f)] = true
                        gotNewRemote = true
                        if f > newestConfirmedFrame { newestConfirmedFrame = f }
                        if f < currentFrame && simulatedRemote[idx(f)] != value {
                            if f < rollbackTo { rollbackTo = f }
                        }
                    }
                }
                f += 1
            }
        }
        advanceFrontier()
        framesSinceRemoteInput = gotNewRemote ? 0 : framesSinceRemoteInput + 1

        // 3. Roll back and re-simulate to the tip if a prediction was wrong.
        if rollbackTo < currentFrame {
            rollbackCount += 1
            currentFrame = rollbackTo
            while currentFrame < resimTarget {
                simulateOneFrame()
            }
        }

        // 4. Simulate the new tip frame, unless we have run as far ahead of
        //    confirmed as we are willing to predict (the prediction barrier).
        if currentFrame - confirmedFrontier >= maxPredictionFrames {
            isStalled = true
        } else {
            isStalled = false
            simulateOneFrame()
        }

        // 5. Drop frames that can never be needed again to bound memory.
        evictConfirmed()

        // 6. Verify any buffered peer checksums that have now confirmed locally.
        if !pendingPeerChecksums.isEmpty { verifyPendingChecksums() }
    }

    // MARK: - Connection health

    public var connectionState: ConnectionState {
        if framesSinceRemoteInput >= disconnectTimeoutFrames { return .disconnected }
        if framesSinceRemoteInput >= unstableTimeoutFrames { return .unstable }
        return .healthy
    }

    /// How far the (possibly predicted) tip currently leads the confirmed frame.
    public var predictionHorizon: Int { max(0, currentFrame - confirmedFrame) }

    // MARK: - Memory window diagnostics

    public var oldestRetainedFrame: Int { baseFrame }
    public var retainedFrameCount: Int { states.count }

    // MARK: - Desync detection

    /// The newest fully-confirmed frame and its state hash, for the peer to check.
    public func localChecksum() -> ChecksumReport? {
        let f = confirmedFrame
        guard f >= baseFrame, f <= currentFrame else { return nil }
        return ChecksumReport(frame: f, hash: stateHash(states[idx(f)]))
    }

    /// Compare a peer's confirmed-frame hash against ours. If the matching frame
    /// is not confirmed locally yet it is buffered and checked once it confirms,
    /// so detection works regardless of which peer is ahead. Frames already
    /// evicted (too old to verify) are dropped. Trips `desyncDetected` on the
    /// first disagreement.
    public func ingestPeerChecksum(frame: Int, hash: UInt64) {
        guard !desyncDetected else { return }
        if frame < baseFrame { return } // evicted - can no longer verify
        pendingPeerChecksums[frame] = hash
        verifyPendingChecksums()
    }

    private func verifyPendingChecksums() {
        if desyncDetected { pendingPeerChecksums.removeAll(); return }
        let confirmed = confirmedFrame
        var resolved: [Int] = []
        for (frame, hash) in pendingPeerChecksums {
            if frame < baseFrame {
                resolved.append(frame)                     // evicted before we could check
            } else if frame <= confirmed {
                if stateHash(states[idx(frame)]) != hash {
                    desyncDetected = true
                    desyncFrame = frame
                    pendingPeerChecksums.removeAll()
                    return
                }
                resolved.append(frame)
            }
        }
        for f in resolved { pendingPeerChecksums[f] = nil }
    }

    // MARK: - Internals

    private func idx(_ frame: Int) -> Int { frame - baseFrame }

    private func simulateOneFrame() {
        ensureCapacity(upTo: currentFrame)
        let localValue = localInputs[idx(currentFrame)]
        let remoteValue = remoteConfirmed[idx(currentFrame)] ? remoteInputs[idx(currentFrame)] : predictRemote()
        simulatedRemote[idx(currentFrame)] = remoteValue

        var next = states[idx(currentFrame)]
        Simulation.tick(state: &next, inputs: ordered(localValue, remoteValue), map: map, config: config)

        let nextIndex = idx(currentFrame + 1)
        if states.count <= nextIndex {
            states.append(next)
        } else {
            states[nextIndex] = next
        }
        currentFrame += 1
    }

    private func predictRemote() -> InputCommand {
        guard newestConfirmedFrame >= baseFrame else { return .neutral }
        return remoteInputs[idx(newestConfirmedFrame)]
    }

    private func ordered(_ local: InputCommand, _ remote: InputCommand) -> [InputCommand] {
        var arr = [InputCommand](repeating: .neutral, count: 2)
        arr[localPlayer] = local
        arr[remotePlayer] = remote
        return arr
    }

    private func advanceFrontier() {
        while idx(confirmedFrontier) < remoteConfirmed.count && remoteConfirmed[idx(confirmedFrontier)] {
            confirmedFrontier += 1
        }
    }

    private func sendLocalWindow(endFrame: Int) {
        let start = max(baseFrame, endFrame - redundancy + 1)
        var window: [InputCommand] = []
        window.reserveCapacity(endFrame - start + 1)
        var f = start
        while f <= endFrame {
            window.append(localInputs[idx(f)])
            f += 1
        }
        transport.send(InputPacket(player: localPlayer, startFrame: start, inputs: window))
    }

    private func ensureCapacity(upTo frame: Int) {
        let needed = frame - baseFrame + 1
        while localInputs.count < needed {
            localInputs.append(.neutral)
            remoteInputs.append(.neutral)
            remoteConfirmed.append(false)
            simulatedRemote.append(.neutral)
        }
    }

    // Evict frames strictly older than the confirmed frontier (minus a small
    // safety margin). Such frames are fully agreed and can never be a rollback
    // target, so dropping them is lossless for correctness and caps memory.
    private func evictConfirmed() {
        let keepFrom = max(baseFrame, min(confirmedFrontier, currentFrame) - retainBehindConfirmed)
        let drop = keepFrom - baseFrame
        guard drop > 0 else { return }
        states.removeFirst(min(drop, states.count))
        localInputs.removeFirst(min(drop, localInputs.count))
        remoteInputs.removeFirst(min(drop, remoteInputs.count))
        remoteConfirmed.removeFirst(min(drop, remoteConfirmed.count))
        simulatedRemote.removeFirst(min(drop, simulatedRemote.count))
        baseFrame = keepFrom
    }
}
