import XCTest
@testable import ArrowClashSim

final class MovementTests: XCTestCase {

    private func emptyMap() -> TileMap {
        return TileMap(cols: 20, rows: 12, solid: [Bool](repeating: false, count: 20 * 12))
    }

    private func neutral() -> [InputCommand] {
        return [.neutral, .neutral]
    }

    // A dropped player falls under gravity and comes to rest on top of the
    // central platform at the spawn Y, with zero vertical velocity.
    func testGravityAndLanding() {
        let map = TileMap.defaultArena()
        let config = GameConfig.default

        var state = GameState.initial(config: config, seed: 1)
        state.phase = .playing // these tests exercise live gameplay, skip countdown
        // Lift player 0 above the platform; keep x over the platform.
        state.players[0].pos.y = Fixed(40)

        for _ in 0..<180 {
            Simulation.tick(state: &state, inputs: neutral(), map: map, config: config)
        }

        XCTAssertTrue(state.players[0].onGround)
        XCTAssertEqual(state.players[0].pos.y, Fixed(config.spawnY))
        XCTAssertEqual(state.players[0].vel.y, .zero)
    }

    // Holding right in open space accelerates horizontal velocity up to the cap
    // and never beyond it.
    func testRunSpeedClampsToMax() {
        let map = emptyMap()
        let config = GameConfig.default

        var state = GameState.initial(config: config, seed: 1)
        state.phase = .playing // these tests exercise live gameplay, skip countdown
        let right = InputCommand(buttons: [.right])

        for _ in 0..<60 {
            Simulation.tick(state: &state, inputs: [right, .neutral], map: map, config: config)
            XCTAssertLessThanOrEqual(state.players[0].vel.x.raw, config.runMaxSpeed.raw)
        }

        XCTAssertEqual(state.players[0].vel.x, config.runMaxSpeed)
        XCTAssertEqual(state.players[0].facing, 1)
    }

    // A dash sets the dash velocity for the dash duration, then the move goes on
    // cooldown. A fresh dash press during cooldown is ignored.
    func testDashRespectsCooldown() {
        let map = TileMap.defaultArena()
        let config = GameConfig.default

        var state = GameState.initial(config: config, seed: 1)
        state.phase = .playing // these tests exercise live gameplay, skip countdown
        let dash = InputCommand(buttons: [.dash])

        // Tick 0: dash press (player 0 faces right by default).
        Simulation.tick(state: &state, inputs: [dash, .neutral], map: map, config: config)
        XCTAssertEqual(state.players[0].dashActiveTimer, config.dashDurationTicks)
        XCTAssertEqual(state.players[0].vel.x, config.dashSpeed)

        // Let the dash run out (release the button while it finishes).
        var guardCount = 0
        while state.players[0].dashActiveTimer > 0 && guardCount < 100 {
            Simulation.tick(state: &state, inputs: neutral(), map: map, config: config)
            guardCount += 1
        }
        XCTAssertGreaterThan(state.players[0].dashCooldownTimer, 0)

        // Press dash again during cooldown: must be ignored.
        Simulation.tick(state: &state, inputs: [dash, .neutral], map: map, config: config)
        XCTAssertEqual(state.players[0].dashActiveTimer, 0)
    }

    // Jumping off the ground produces upward (negative-y) velocity and leaves
    // the ground.
    func testJumpFromGroundLifts() {
        let map = TileMap.defaultArena()
        let config = GameConfig.default

        var state = GameState.initial(config: config, seed: 1)
        state.phase = .playing // these tests exercise live gameplay, skip countdown
        // Settle onto the platform first.
        for _ in 0..<10 {
            Simulation.tick(state: &state, inputs: neutral(), map: map, config: config)
        }
        XCTAssertTrue(state.players[0].onGround)

        // Jump press.
        let jump = InputCommand(buttons: [.jump])
        Simulation.tick(state: &state, inputs: [jump, .neutral], map: map, config: config)

        XCTAssertFalse(state.players[0].onGround)
        XCTAssertLessThan(state.players[0].vel.y.raw, 0)
    }
}
