import XCTest
@testable import ArrowClashSim

final class MatchFlowTests: XCTestCase {

    private let map = TileMap.defaultArena()
    private let config = GameConfig.default

    private func neutral() -> [InputCommand] { [.neutral, .neutral] }

    // Place a flying arrow inside a player so the next playing tick kills them.
    private func arrowOnPlayer(_ index: Int, owner: Int8, in state: GameState) -> ArrowState {
        let p = state.players[index]
        let center = FixedVec(
            x: p.pos.x + config.playerWidth / Fixed(2),
            y: p.pos.y + config.playerHeight / Fixed(2)
        )
        return ArrowState(pos: center, vel: .zero, active: true, stuck: false, owner: owner, dir: 0)
    }

    func testStartsInCountdownThenPlays() {
        var state = GameState.initial(config: config, seed: 1)
        XCTAssertEqual(state.phase, .countdown)

        for _ in 0..<(Int(config.countdownTicks) - 1) {
            Simulation.tick(state: &state, inputs: neutral(), map: map, config: config)
        }
        XCTAssertEqual(state.phase, .countdown) // still counting down

        Simulation.tick(state: &state, inputs: neutral(), map: map, config: config)
        XCTAssertEqual(state.phase, .playing)
    }

    func testInputsIgnoredDuringCountdown() {
        var state = GameState.initial(config: config, seed: 1)
        let right = InputCommand(buttons: [.right])
        // Hold right during countdown; the player must not move.
        let startX = state.players[0].pos.x
        for _ in 0..<10 {
            Simulation.tick(state: &state, inputs: [right, .neutral], map: map, config: config)
        }
        XCTAssertEqual(state.players[0].pos.x, startX)
        XCTAssertEqual(state.players[0].vel.x, .zero)
    }

    func testArrowKillScoresAndEndsRound() {
        var state = GameState.initial(config: config, seed: 1)
        state.phase = .playing
        state.arrows[0] = arrowOnPlayer(1, owner: 0, in: state)

        Simulation.tick(state: &state, inputs: neutral(), map: map, config: config)

        XCTAssertFalse(state.players[1].alive)
        XCTAssertTrue(state.players[0].alive)
        XCTAssertEqual(state.scores[0], 1)
        XCTAssertEqual(state.scores[1], 0)
        XCTAssertEqual(state.phase, .roundOver)
        XCTAssertEqual(state.phaseTimer, config.roundOverTicks)
    }

    func testRoundResetsAfterRoundOver() {
        var state = GameState.initial(config: config, seed: 1)
        state.phase = .playing
        state.arrows[0] = arrowOnPlayer(1, owner: 0, in: state)
        Simulation.tick(state: &state, inputs: neutral(), map: map, config: config) // round ends

        for _ in 0..<Int(config.roundOverTicks) {
            Simulation.tick(state: &state, inputs: neutral(), map: map, config: config)
        }

        XCTAssertEqual(state.phase, .countdown)
        XCTAssertEqual(state.round, 1)
        XCTAssertEqual(state.scores[0], 1) // score carries over
        XCTAssertTrue(state.players[0].alive)
        XCTAssertTrue(state.players[1].alive)
        XCTAssertEqual(state.players[1].pos.x, Fixed(config.spawnX1)) // respawned
        XCTAssertEqual(state.arrows.filter { $0.active }.count, 0)    // arrows cleared
    }

    func testMatchEndsAtRoundsToWin() {
        var state = GameState.initial(config: config, seed: 1)
        state.phase = .playing
        state.scores[0] = config.roundsToWin - 1 // one win away
        state.arrows[0] = arrowOnPlayer(1, owner: 0, in: state)

        Simulation.tick(state: &state, inputs: neutral(), map: map, config: config) // round ends
        XCTAssertEqual(state.scores[0], config.roundsToWin)
        XCTAssertEqual(state.phase, .roundOver)

        for _ in 0..<Int(config.roundOverTicks) {
            Simulation.tick(state: &state, inputs: neutral(), map: map, config: config)
        }

        XCTAssertEqual(state.phase, .matchOver)
        XCTAssertEqual(state.winner, 0)
    }

    func testDoubleKnockoutScoresForNoOne() {
        var state = GameState.initial(config: config, seed: 1)
        state.phase = .playing
        state.arrows[0] = arrowOnPlayer(1, owner: 0, in: state)
        state.arrows[1] = arrowOnPlayer(0, owner: 1, in: state)

        Simulation.tick(state: &state, inputs: neutral(), map: map, config: config)

        XCTAssertFalse(state.players[0].alive)
        XCTAssertFalse(state.players[1].alive)
        XCTAssertEqual(state.scores[0], 0)
        XCTAssertEqual(state.scores[1], 0)
        XCTAssertEqual(state.phase, .roundOver)
    }

    func testMatchOverIsFrozen() {
        var state = GameState.initial(config: config, seed: 1)
        state.phase = .matchOver
        state.winner = 0
        let posBefore = state.players[0].pos
        let right = InputCommand(buttons: [.right, .jump, .shoot])
        for _ in 0..<30 {
            Simulation.tick(state: &state, inputs: [right, right], map: map, config: config)
        }
        // Nothing moves while the match is over (only the tick counter advances).
        XCTAssertEqual(state.players[0].pos, posBefore)
        XCTAssertEqual(state.phase, .matchOver)
        XCTAssertEqual(state.winner, 0)
    }
}
