import XCTest
@testable import ArrowClashSim

final class MapsTests: XCTestCase {

    func testTenMapsExistAndAreWellFormed() {
        XCTAssertEqual(Maps.all.count, 10)
        for map in Maps.all {
            XCTAssertEqual(map.rows, 12)
            XCTAssertEqual(map.cols, 20)
            XCTAssertEqual(map.spawns.count, 2)
            // Spawn must rest on a solid tile with empty space above it.
            let tiles = map.tileMap()
            for sp in map.spawns {
                let col = sp.x / 16
                let footRow = (sp.y + 14) / 16 // bottom of the player
                XCTAssertTrue(tiles.isSolid(col: col, row: footRow), "\(map.name) spawn not grounded")
                XCTAssertFalse(tiles.isSolid(col: col, row: footRow - 1), "\(map.name) spawn overlaps a wall")
            }
        }
    }

    // Every map must be deterministic: same inputs -> same final hash.
    func testEveryMapIsDeterministic() {
        let config = GameConfig.default
        var s = UInt64(0x1234)
        func rnd() -> UInt32 { s = s &* 6364136223846793005 &+ 1442695040888963407; return UInt32(truncatingIfNeeded: s >> 33) }
        func makeInputs(_ n: Int) -> [[InputCommand]] {
            var out: [[InputCommand]] = []
            for _ in 0..<n {
                var pair: [InputCommand] = []
                for _ in 0..<2 {
                    pair.append(InputCommand(buttons: InputCommand.Buttons(rawValue: UInt8(truncatingIfNeeded: rnd()) & 0b11111),
                                             aim: UInt8(truncatingIfNeeded: rnd())))
                }
                out.append(pair)
            }
            return out
        }

        for map in Maps.all {
            let inputs = makeInputs(400)
            let tiles = map.tileMap()
            var a = GameState.initial(map: map, config: config, seed: 5)
            var b = GameState.initial(map: map, config: config, seed: 5)
            for t in 0..<inputs.count {
                Simulation.tick(state: &a, inputs: inputs[t], map: tiles, config: config)
                Simulation.tick(state: &b, inputs: inputs[t], map: tiles, config: config)
            }
            XCTAssertEqual(stateHash(a), stateHash(b), "map \(map.name) not deterministic")
        }
    }

    // Players should settle (rest, alive) at spawn during the opening countdown.
    func testPlayersRestAtSpawnDuringCountdown() {
        let config = GameConfig.default
        for map in Maps.all {
            let tiles = map.tileMap()
            var state = GameState.initial(map: map, config: config, seed: 1)
            for _ in 0..<40 {
                Simulation.tick(state: &state, inputs: [.neutral, .neutral], map: tiles, config: config)
            }
            for p in state.players {
                XCTAssertTrue(p.alive)
                XCTAssertTrue(p.onGround, "\(map.name): player did not settle on ground")
            }
        }
    }
}
