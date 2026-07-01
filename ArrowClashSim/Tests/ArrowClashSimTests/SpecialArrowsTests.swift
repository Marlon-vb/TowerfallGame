import XCTest
@testable import ArrowClashSim

final class SpecialArrowsTests: XCTestCase {

    private let map = TileMap.defaultArena()
    private let config = GameConfig.default
    private func neutral() -> [InputCommand] { [.neutral, .neutral] }

    private func playingState(seed: UInt64 = 1) -> GameState {
        var state = GameState.initial(config: config, seed: seed)
        state.phase = .playing
        return state
    }

    // MARK: - Chest

    func testChestSpawnsAfterDelayAtAChestSpot() {
        var state = playingState()
        XCTAssertFalse(state.chest.active)
        for _ in 0..<Int(config.chestDelayTicks) {
            Simulation.tick(state: &state, inputs: neutral(), map: map, config: config)
        }
        XCTAssertTrue(state.chest.active, "chest should appear after the delay")
        XCTAssertTrue(state.chestSpots.contains(state.chest.pos), "chest must be at a map chest spot")
        let kind = ArrowKind(rawValue: state.chest.kind)
        XCTAssertNotNil(kind)
        XCTAssertNotEqual(kind, ArrowKind.normal)
    }

    func testChestPickupGrantsSpecialArrows() {
        var state = playingState()
        for _ in 0..<Int(config.chestDelayTicks) {
            Simulation.tick(state: &state, inputs: neutral(), map: map, config: config)
        }
        XCTAssertTrue(state.chest.active)
        // Teleport player 0 onto the chest.
        state.players[0].pos = FixedVec(
            x: state.chest.pos.x - config.playerWidth / Fixed(2),
            y: state.chest.pos.y - config.playerHeight / Fixed(2)
        )
        let kind = state.chest.kind
        Simulation.tick(state: &state, inputs: neutral(), map: map, config: config)
        XCTAssertFalse(state.chest.active, "chest consumed")
        XCTAssertEqual(state.players[0].specialKind, kind)
        XCTAssertEqual(state.players[0].specialCount, config.chestArrowCount)
    }

    func testChestResetsEachRound() {
        var state = playingState()
        // Kill player 1 to end the round, then run through roundOver + countdown.
        state.players[1].alive = false
        Simulation.tick(state: &state, inputs: neutral(), map: map, config: config)
        XCTAssertEqual(state.phase, .roundOver)
        var guardTicks = 0
        while state.phase != .playing && guardTicks < 1000 {
            Simulation.tick(state: &state, inputs: neutral(), map: map, config: config)
            guardTicks += 1
        }
        XCTAssertEqual(state.phase, .playing)
        XCTAssertFalse(state.chest.active)
        XCTAssertEqual(state.chest.spawnTimer, config.chestDelayTicks, "chest timer restarts per round")
    }

    // MARK: - Firing specials

    func testSpecialArrowsFireBeforeNormalOnes() {
        var state = playingState()
        state.players[0].specialKind = ArrowKind.laser.rawValue
        state.players[0].specialCount = 1
        let normalBefore = state.players[0].arrows

        let shoot = InputCommand(buttons: [.shoot], aim: 0)
        Simulation.tick(state: &state, inputs: [shoot, .neutral], map: map, config: config)

        XCTAssertEqual(state.players[0].arrows, normalBefore, "normal quiver untouched")
        XCTAssertEqual(state.players[0].specialCount, 0)
        XCTAssertEqual(state.players[0].specialKind, 0, "stash kind clears when empty")
        let arrow = state.arrows.first { $0.active }
        XCTAssertEqual(arrow?.arrowKind, .laser)
        XCTAssertEqual(arrow?.vel.x, config.laserSpeed)
    }

    // MARK: - Flight behavior

    func testLaserFliesStraightNoGravity() {
        var state = playingState()
        state.players[0].specialKind = ArrowKind.laser.rawValue
        state.players[0].specialCount = 1
        let shoot = InputCommand(buttons: [.shoot], aim: 0)
        Simulation.tick(state: &state, inputs: [shoot, .neutral], map: map, config: config)
        for _ in 0..<5 {
            Simulation.tick(state: &state, inputs: neutral(), map: map, config: config)
        }
        if let arrow = state.arrows.first(where: { $0.active && !$0.stuck }) {
            XCTAssertEqual(arrow.vel.y, .zero, "laser must not drop")
        }
    }

    func testDrillPassesThroughTiles() {
        var state = playingState()
        // Fire a drill straight down at the floor under the spawn: a normal
        // arrow sticks, a drill must pass through and keep flying (wrapping).
        state.arrows[0] = ArrowState(
            pos: FixedVec(x: Fixed(24), y: Fixed(170)),
            vel: FixedVec(x: .zero, y: config.arrowSpeed),
            active: true, stuck: false, owner: 0, dir: 64,
            kind: ArrowKind.drill.rawValue
        )
        for _ in 0..<4 {
            Simulation.tick(state: &state, inputs: neutral(), map: map, config: config)
        }
        let drill = state.arrows[0]
        XCTAssertTrue(drill.active)
        XCTAssertFalse(drill.stuck, "drill must never stick in a tile")
    }

    func testFeatherExpiresAfterItsLifetime() {
        var state = playingState()
        // Row y=150 is an empty corridor across the whole default map, so the
        // feather wraps freely until its lifetime ends.
        state.arrows[0] = ArrowState(
            pos: FixedVec(x: Fixed(160), y: Fixed(150)),
            vel: FixedVec(x: config.featherSpeed, y: .zero),
            active: true, stuck: false, owner: 0, dir: 0,
            kind: ArrowKind.feather.rawValue
        )
        // Move player 1 out of the feather's flight row so it survives to TTL.
        state.players[1].pos = FixedVec(x: Fixed(4), y: Fixed(162))
        for _ in 0...Int(config.featherLifeTicks) {
            Simulation.tick(state: &state, inputs: neutral(), map: map, config: config)
        }
        XCTAssertFalse(state.arrows[0].active, "feather expires at end of life")
    }

    // MARK: - Bomb

    func testBombSplashKillsNearbyPlayerOnTileImpact() {
        var state = playingState()
        // Both players stand on the left floor; a bomb lands between them.
        state.players[0].pos = FixedVec(x: Fixed(10), y: Fixed(162))
        state.players[1].pos = FixedVec(x: Fixed(40), y: Fixed(162))
        state.arrows[0] = ArrowState(
            pos: FixedVec(x: Fixed(28), y: Fixed(170)),
            vel: FixedVec(x: .zero, y: config.arrowSpeed),
            active: true, stuck: false, owner: 0, dir: 64,
            kind: ArrowKind.bomb.rawValue
        )
        Simulation.tick(state: &state, inputs: neutral(), map: map, config: config)
        XCTAssertFalse(state.players[0].alive, "owner dies to their own bomb splash")
        XCTAssertFalse(state.players[1].alive, "nearby player dies to the splash")
        XCTAssertFalse(state.arrows[0].active, "bomb is consumed by the explosion")
    }

    // MARK: - Catch/pickup of specials

    func testDashCatchingSpecialRefillsSpecialStash() {
        var state = playingState()
        state.players[0].arrows = 0
        let center = FixedVec(
            x: state.players[0].pos.x + config.playerWidth / Fixed(2),
            y: state.players[0].pos.y + config.playerHeight / Fixed(2)
        )
        state.arrows[0] = ArrowState(
            pos: FixedVec(x: center.x + config.laserSpeed, y: center.y),
            vel: FixedVec(x: -config.laserSpeed, y: .zero),
            active: true, stuck: false, owner: 1, dir: 128,
            kind: ArrowKind.laser.rawValue
        )
        state.players[0].dashActiveTimer = 2
        Simulation.tick(state: &state, inputs: neutral(), map: map, config: config)
        XCTAssertTrue(state.players[0].alive)
        XCTAssertEqual(state.players[0].specialKind, ArrowKind.laser.rawValue)
        XCTAssertEqual(state.players[0].specialCount, 1)
        XCTAssertEqual(state.players[0].arrows, 0, "special goes to the stash, not the quiver")
    }

    // MARK: - Hash coverage

    func testHashCoversSpecialFields() {
        let a = playingState()
        var b = a
        b.players[0].specialCount = 1
        b.players[0].specialKind = ArrowKind.bomb.rawValue
        XCTAssertNotEqual(stateHash(a), stateHash(b))

        var c = a
        c.chest.kind = ArrowKind.drill.rawValue
        XCTAssertNotEqual(stateHash(a), stateHash(c))

        var d = a
        d.arrows[0].kind = ArrowKind.feather.rawValue
        XCTAssertNotEqual(stateHash(a), stateHash(d))
    }
}
