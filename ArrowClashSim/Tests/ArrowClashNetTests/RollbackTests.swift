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
        for f in 0...confirmed {
            XCTAssertEqual(stateHash(a.stateAt(frame: f)), stateHash(b.stateAt(frame: f)),
                           "peers disagree at confirmed frame \(f)")
        }
    }
}
