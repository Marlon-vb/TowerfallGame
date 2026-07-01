import XCTest
@testable import ArrowClashSim

final class CombatTests: XCTestCase {

    private func neutral() -> [InputCommand] { [.neutral, .neutral] }

    func testShootConsumesQuiverAndSpawnsArrow() {
        let map = TileMap.defaultArena()
        let config = GameConfig.default
        var state = GameState.initial(config: config, seed: 1)
        state.phase = .playing

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
        state.phase = .playing

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
        state.phase = .playing

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
        state.phase = .playing

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

    // MARK: - Dash-catch

    // Places an enemy arrow one tick of flight away from the player's center so
    // that after stepArrow moves it, it lands inside the player's AABB.
    private func incomingArrow(at player: PlayerState, config: GameConfig, owner: Int8) -> ArrowState {
        let center = FixedVec(
            x: player.pos.x + config.playerWidth / Fixed(2),
            y: player.pos.y + config.playerHeight / Fixed(2)
        )
        // Flying right-to-left at arrowSpeed: spawn arrowSpeed to the right.
        return ArrowState(
            pos: FixedVec(x: center.x + config.arrowSpeed, y: center.y),
            vel: FixedVec(x: -config.arrowSpeed, y: .zero),
            active: true,
            stuck: false,
            owner: owner,
            dir: 128
        )
    }

    func testDashCatchesEnemyArrowInsteadOfDying() {
        let map = TileMap.defaultArena()
        let config = GameConfig.default
        var state = GameState.initial(config: config, seed: 1)
        state.phase = .playing
        state.players[0].arrows = 0

        state.arrows[0] = incomingArrow(at: state.players[0], config: config, owner: 1)
        // Mid-dash this tick (timer decrements at the start of step, so use 2
        // to still be dashing when deaths resolve).
        state.players[0].dashActiveTimer = 2

        Simulation.tick(state: &state, inputs: neutral(), map: map, config: config)

        XCTAssertTrue(state.players[0].alive, "dashing player must not die to a caught arrow")
        XCTAssertEqual(state.players[0].arrows, 1, "caught arrow refills the quiver")
        XCTAssertEqual(state.arrows.filter { $0.active }.count, 0)
        XCTAssertEqual(state.phase, .playing, "no death, so the round continues")
    }

    func testSameArrowKillsWithoutDash() {
        let map = TileMap.defaultArena()
        let config = GameConfig.default
        var state = GameState.initial(config: config, seed: 1)
        state.phase = .playing

        state.arrows[0] = incomingArrow(at: state.players[0], config: config, owner: 1)
        // Not dashing.
        Simulation.tick(state: &state, inputs: neutral(), map: map, config: config)

        XCTAssertFalse(state.players[0].alive, "the identical arrow kills when not dashing")
        XCTAssertEqual(state.phase, .roundOver)
    }

    func testDashCatchWithFullQuiverStillProtects() {
        let map = TileMap.defaultArena()
        let config = GameConfig.default
        var state = GameState.initial(config: config, seed: 1)
        state.phase = .playing
        state.players[0].arrows = config.startingArrows

        state.arrows[0] = incomingArrow(at: state.players[0], config: config, owner: 1)
        state.players[0].dashActiveTimer = 2

        Simulation.tick(state: &state, inputs: neutral(), map: map, config: config)

        XCTAssertTrue(state.players[0].alive)
        XCTAssertEqual(state.players[0].arrows, config.startingArrows, "quiver capped")
        XCTAssertEqual(state.arrows.filter { $0.active }.count, 0, "arrow is swatted dead either way")
    }
}
