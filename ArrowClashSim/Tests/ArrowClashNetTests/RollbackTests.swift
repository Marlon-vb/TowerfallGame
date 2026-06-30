import XCTest
@testable import ArrowClashNet
import ArrowClashSim

final class RollbackTests: XCTestCase {

    // With no latency the sessions stay essentially current and agree with a
    // full-information replay at every confirmed frame.
    func testNoLatencyMatchesReference() {
        let r = RollbackHarness.run(.init(frames: 600, latency: 0, seed: 1))
        XCTAssertTrue(r.matchedReference, "first mismatch at \(String(describing: r.firstMismatch))")
        XCTAssertGreaterThanOrEqual(r.maxConfirmed, 600 - 10)
    }

    // Latency above the input delay forces prediction and rollback, but every
    // confirmed frame must still equal the reference.
    func testLatencyCausesRollbackButStaysCorrect() {
        let r = RollbackHarness.run(.init(frames: 600, inputDelay: 2, latency: 6, seed: 2))
        XCTAssertTrue(r.matchedReference, "first mismatch at \(String(describing: r.firstMismatch))")
        XCTAssertGreaterThan(r.rollbacksA, 0)
        XCTAssertGreaterThan(r.rollbacksB, 0)
        XCTAssertGreaterThanOrEqual(r.maxConfirmed, 600 - 16)
    }

    // Packet loss plus jitter: the redundant input window recovers drops, and
    // confirmed frames still match the reference.
    func testLossyLinkStaysCorrect() {
        let r = RollbackHarness.run(.init(frames: 800, inputDelay: 2, latency: 5, jitter: 3, lossPerThousand: 200, seed: 3))
        XCTAssertTrue(r.matchedReference, "first mismatch at \(String(describing: r.firstMismatch))")
        XCTAssertGreaterThanOrEqual(r.maxConfirmed, 800 - 60)
    }

    // Fuzz across many seeds and network conditions. The whole point of rollback
    // is that the confirmed timeline is identical for both peers regardless of
    // how inputs were delayed, dropped or reordered.
    func testFuzzAllScenariosMatchReference() {
        for seed in UInt64(1)...UInt64(60) {
            let latency = Int(seed % 9)
            let loss = UInt32((seed * 41) % 300)
            let jitter = Int(seed % 5)
            let r = RollbackHarness.run(.init(frames: 400, inputDelay: 2, latency: latency, jitter: jitter, lossPerThousand: loss, seed: seed))
            XCTAssertTrue(r.matchedReference,
                          "seed \(seed) latency \(latency) loss \(loss) jitter \(jitter): mismatch at \(String(describing: r.firstMismatch))")
            XCTAssertGreaterThanOrEqual(r.maxConfirmed, 400 - 90,
                                        "seed \(seed): confirmed only reached \(r.maxConfirmed)")
        }
    }

    // A directly-built scenario to sanity-check the network and confirmed-frame
    // accounting without the harness wrapper.
    func testConfirmedFrameAdvancesAndStatesAgreeAcrossPeers() {
        let config = GameConfig.default
        let seed: UInt64 = 7
        let frames = 300
        let raw = RollbackHarness.makeInputs(frames: frames, seed: 99)
        let net = SimulatedNetwork(latency: 3, jitter: 1, lossPerThousand: 100, seed: 5)
        let a = RollbackSession(localPlayer: 0, transport: net.endpointA, config: config, seed: seed)
        let b = RollbackSession(localPlayer: 1, transport: net.endpointB, config: config, seed: seed)

        for f in 0..<frames {
            a.step(localInput: raw[0][f])
            b.step(localInput: raw[1][f])
            net.advance()
        }

        let confirmed = min(a.confirmedFrame, b.confirmedFrame)
        XCTAssertGreaterThan(confirmed, 0)
        // Memory is bounded, so only the retained window is addressable.
        let start = max(a.oldestRetainedFrame, b.oldestRetainedFrame)
        for f in start...confirmed {
            XCTAssertEqual(stateHash(a.stateAt(frame: f)), stateHash(b.stateAt(frame: f)),
                           "peers disagree at confirmed frame \(f)")
        }
    }

    // MARK: - Phase 10.1 hardening

    // Memory must stay bounded over a long, lossy match: old confirmed frames are
    // evicted, so the retained window stays small while confirmed frames still
    // match the reference and no false desync is reported.
    func testBoundedMemoryOverLongMatch() {
        let r = RollbackHarness.run(.init(frames: 5000, inputDelay: 2, latency: 5, jitter: 3, lossPerThousand: 150, seed: 11))
        XCTAssertTrue(r.matchedReference, "first mismatch at \(String(describing: r.firstMismatch))")
        XCTAssertFalse(r.desyncDetected, "checksum exchange should not flag a healthy match")
        // Window is bounded by the prediction horizon + margins, nowhere near the
        // 5000 frames played. Generous ceiling to stay robust across seeds.
        XCTAssertLessThan(r.maxRetainedWindow, 256,
                          "retained window grew to \(r.maxRetainedWindow); memory is not bounded")
    }

    // The checksum exchange must not raise false positives on any fuzzed link.
    func testNoFalseDesyncAcrossScenarios() {
        for seed in UInt64(1)...UInt64(40) {
            let r = RollbackHarness.run(.init(frames: 500, inputDelay: 2,
                                              latency: Int(seed % 8), jitter: Int(seed % 4),
                                              lossPerThousand: UInt32((seed * 37) % 250), seed: seed))
            XCTAssertFalse(r.desyncDetected, "seed \(seed) reported a false desync")
            XCTAssertTrue(r.matchedReference, "seed \(seed) mismatch at \(String(describing: r.firstMismatch))")
        }
    }

    // Two sessions seeded differently diverge; the checksum exchange must catch it
    // at a confirmed frame (the safety net behind the determinism guarantee).
    func testDesyncIsDetectedWhenSessionsDiverge() {
        let config = GameConfig.default
        let frames = 200
        let raw = RollbackHarness.makeInputs(frames: frames, seed: 99)
        let net = SimulatedNetwork(latency: 2, seed: 5)
        // Different seeds -> different initial RNG state -> divergent confirmed states.
        let a = RollbackSession(localPlayer: 0, transport: net.endpointA, config: config, seed: 1)
        let b = RollbackSession(localPlayer: 1, transport: net.endpointB, config: config, seed: 2)

        for f in 0..<frames {
            a.step(localInput: raw[0][f])
            b.step(localInput: raw[1][f])
            net.advance()
            if let ca = a.localChecksum() { b.ingestPeerChecksum(frame: ca.frame, hash: ca.hash) }
            if let cb = b.localChecksum() { a.ingestPeerChecksum(frame: cb.frame, hash: cb.hash) }
        }

        XCTAssertTrue(a.desyncDetected || b.desyncDetected, "diverging sessions were not detected")
    }

    // When the peer goes silent the session must hit the prediction barrier
    // (stall instead of predicting forever), stop advancing the tip, and report
    // the link as disconnected past the timeout.
    func testStallAndDisconnectOnOutage() {
        let config = GameConfig.default
        let net = SimulatedNetwork(latency: 2, seed: 1)
        let a = RollbackSession(localPlayer: 0, transport: net.endpointA, config: config, seed: 7,
                                inputDelay: 2, maxPredictionFrames: 10,
                                unstableTimeoutFrames: 10, disconnectTimeoutFrames: 40)
        let b = RollbackSession(localPlayer: 1, transport: net.endpointB, config: config, seed: 7,
                                inputDelay: 2)

        // Warm up a healthy link.
        for _ in 0..<20 {
            a.step(localInput: .neutral)
            b.step(localInput: .neutral)
            net.advance()
        }
        XCTAssertEqual(a.connectionState, .healthy)
        XCTAssertFalse(a.isStalled)

        // Outage: peer B stops stepping (and thus stops sending). Keep driving A.
        for _ in 0..<60 {
            a.step(localInput: .neutral)
            net.advance()
        }
        XCTAssertTrue(a.isStalled, "session should stall at the prediction barrier")
        XCTAssertEqual(a.connectionState, .disconnected, "silent peer past timeout should read as disconnected")

        // Fully stalled: the tip must not keep advancing.
        let frozen = a.currentFrame
        for _ in 0..<10 {
            a.step(localInput: .neutral)
            net.advance()
        }
        XCTAssertEqual(a.currentFrame, frozen, "tip advanced while fully stalled")
    }
}
