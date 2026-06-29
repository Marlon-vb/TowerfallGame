// SceneDriver.swift
// Abstracts "advance the game by one 60 Hz tick and give me states to render"
// so the same GameScene renders both local practice and an online rollback
// match. The scene owns the fixed-timestep clock and interpolation; the driver
// owns how a tick is produced.

import ArrowClashSim
import ArrowClashNet

protocol SceneDriver: AnyObject {
    var localPlayer: Int { get }
    func advance(localInput: InputCommand)
    func renderStates() -> (previous: GameState, current: GameState)
}

// Local single-player practice: player 1 is an idle dummy.
final class LocalDriver: SceneDriver {
    let localPlayer = 0
    private let map = TileMap.defaultArena()
    private let config: GameConfig
    private var current: GameState
    private var previous: GameState

    init(config: GameConfig = .default, seed: UInt64 = 1) {
        self.config = config
        let s = GameState.initial(config: config, seed: seed)
        self.current = s
        self.previous = s
    }

    func advance(localInput: InputCommand) {
        previous = current
        Simulation.tick(state: &current, inputs: [localInput, .neutral], map: map, config: config)
    }

    func renderStates() -> (previous: GameState, current: GameState) {
        return (previous, current)
    }
}

// Online: drives a rollback session. latestState may jump on a rollback, so the
// scene's wrap-aware interpolation will snap rather than slide on big changes.
final class OnlineDriver: SceneDriver {
    let localPlayer: Int
    private let session: RollbackSession
    private var previous: GameState

    init(session: RollbackSession) {
        self.session = session
        self.localPlayer = session.localPlayer
        self.previous = session.latestState
    }

    func advance(localInput: InputCommand) {
        previous = session.latestState
        session.step(localInput: localInput)
    }

    func renderStates() -> (previous: GameState, current: GameState) {
        return (previous, session.latestState)
    }
}
