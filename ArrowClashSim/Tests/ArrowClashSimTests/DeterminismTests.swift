import XCTest
@testable import ArrowClashSim

final class DeterminismTests: XCTestCase {

    // A scripted input sequence generated from a plain LCG. This driver PRNG is
    // a TEST helper only; it is not part of the game state. It exists just to
    // produce a varied but reproducible stream of inputs.
    private func makeInputs(count: Int, seed: UInt64) -> [[InputCommand]] {
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

    // Phase 0 acceptance: run the same input sequence twice and assert the
    // final state is byte-for-byte identical via the state hash (and full
    // equality).
    func testIdenticalReplayProducesIdenticalState() {
        let map = TileMap.defaultArena()
        let config = GameConfig.default
        let inputs = makeInputs(count: 1200, seed: 0xA11CE)

        var a = GameState.initial(config: config, seed: 1)
        var b = GameState.initial(config: config, seed: 1)

        for t in 0..<inputs.count {
            Simulation.tick(state: &a, inputs: inputs[t], map: map, config: config)
            Simulation.tick(state: &b, inputs: inputs[t], map: map, config: config)
            // Stronger than just final-state equality: assert per-tick parity.
            XCTAssertEqual(stateHash(a), stateHash(b), "diverged at tick \(t)")
        }

        XCTAssertEqual(stateHash(a), stateHash(b))
        XCTAssertEqual(a, b)
    }

    // Snapshot/restore is the operation rollback depends on. Copy the value-type
    // state mid-run, advance the copy and the original with the same inputs, and
    // assert they stay identical. Proves the state carries no hidden shared
    // reference and that a plain copy is a valid snapshot.
    func testSnapshotRestoreStaysInSync() {
        let map = TileMap.defaultArena()
        let config = GameConfig.default
        let inputs = makeInputs(count: 600, seed: 0xBEEF)

        var live = GameState.initial(config: config, seed: 7)
        for t in 0..<300 {
            Simulation.tick(state: &live, inputs: inputs[t], map: map, config: config)
        }

        // Snapshot by value copy.
        var restored = live

        for t in 300..<600 {
            Simulation.tick(state: &live, inputs: inputs[t], map: map, config: config)
            Simulation.tick(state: &restored, inputs: inputs[t], map: map, config: config)
        }

        XCTAssertEqual(stateHash(live), stateHash(restored))
        XCTAssertEqual(live, restored)
    }

    // The hash must actually be sensitive to state changes, otherwise the test
    // above proves nothing. Two different input streams must diverge.
    func testDifferentInputsProduceDifferentState() {
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

        XCTAssertNotEqual(stateHash(a), stateHash(b))
    }
}
