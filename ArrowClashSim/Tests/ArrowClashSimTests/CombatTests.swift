import XCTest
@testable import ArrowClashSim

final class CombatTests: XCTestCase {

    private func neutral() -> [InputCommand] { [.neutral, .neutral] }

    func testShootConsumesQuiverAndSpawnsArrow() {
        let map = TileMap.defaultArena()
        let config = GameConfig.default
        var state = GameState.initial(config: config, seed: 1)

        let shoot = InputCommand(buttons: [.shoot], aim: 0) // aim right
        Simulation.tick(state: &state, inputs: [shoot, .neutral], map: map, config: config)

        XCTAssertEqual(state.players[0].arrows, config.startingArrows - 1)
        let active = state.arrows.filter { $0.active }
        XCTAssertEqual(active.count, 1)
        XCTAssertEqual(active.first?.owner, 0)
        XCTAssertEqual(active.first?.vel.x, config.arrowSpeed)
    }

    func testShootRequiresPressEdge() {
        let map = TileMap.defaultArena()
        let config = GameConfig.default
        var state = GameState.initial(config: config, seed: 1)

        // Holding shoot for several ticks should fire exactly once (edge), not
        // drain the whole quiver.
        let shoot = InputCommand(buttons: [.shoot], aim: 0)
        for _ in 0..<5 {
            Simulation.tick(state: &state, inputs: [shoot, .neutral], map: map, config: config)
        }
        XCTAssertEqual(state.players[0].arrows, config.startingArrows - 1)
        XCTAssertEqual(state.arrows.filter { $0.active }.count, 1)
    }

    func testReclaimStuckArrow() {
        let map = TileMap.defaultArena()
        let config = GameConfig.default
        var state = GameState.initial(config: config, seed: 1)

        let center = FixedVec(
            x: state.players[0].pos.x + config.playerWidth / Fixed(2),
            y: state.players[0].pos.y + config.playerHeight / Fixed(2)
        )
        state.arrows[0] = ArrowState(pos: center, active: true, stuck: true, owner: 1, dir: 0)
        state.players[0].arrows = config.startingArrows - 1

        Simulation.tick(state: &state, inputs: neutral(), map: map, config: config)

        XCTAssertEqual(state.players[0].arrows, config.startingArrows)
        XCTAssertEqual(state.arrows.filter { $0.active }.count, 0)
    }

    func testFullQuiverDoesNotReclaim() {
        let map = TileMap.defaultArena()
        let config = GameConfig.default
        var state = GameState.initial(config: config, seed: 1)

        let center = FixedVec(
            x: state.players[0].pos.x + config.playerWidth / Fixed(2),
            y: state.players[0].pos.y + config.playerHeight / Fixed(2)
        )
        state.arrows[0] = ArrowState(pos: center, active: true, stuck: true, owner: 1, dir: 0)
        // Quiver already full.
        state.players[0].arrows = config.startingArrows

        Simulation.tick(state: &state, inputs: neutral(), map: map, config: config)

        XCTAssertEqual(state.arrows.filter { $0.active }.count, 1)
    }
}
