// GameState.swift
// The full mutable simulation state. Plain value types only, no references, so
// a copy is a snapshot and assignment is a restore. This is what rollback
// saves and rewinds.
//
// players is a fixed two-element array, always iterated in index order (0 then
// 1) so iteration order is deterministic.

// Round/match lifecycle, part of the deterministic state so it rolls back too.
public enum MatchPhase: Int, Equatable {
    case countdown = 0  // frozen pre-round countdown
    case playing = 1    // live fight
    case roundOver = 2  // brief result pause after a death
    case matchOver = 3  // someone reached roundsToWin
}

public struct GameState: Equatable {
    public var tick: UInt32
    public var players: [PlayerState]
    // Fixed-capacity arrow pool (startingArrows per player). Stable indices.
    public var arrows: [ArrowState]
    public var rng: DeterministicRandom

    // Match flow.
    public var phase: MatchPhase
    public var phaseTimer: Int32   // ticks remaining in countdown / roundOver
    public var scores: [Int]       // round wins per player
    public var round: Int          // 0-based round index
    public var winner: Int8        // -1 until matchOver, then the winning player

    public init(
        tick: UInt32,
        players: [PlayerState],
        arrows: [ArrowState],
        rng: DeterministicRandom,
        phase: MatchPhase,
        phaseTimer: Int32,
        scores: [Int],
        round: Int,
        winner: Int8
    ) {
        self.tick = tick
        self.players = players
        self.arrows = arrows
        self.rng = rng
        self.phase = phase
        self.phaseTimer = phaseTimer
        self.scores = scores
        self.round = round
        self.winner = winner
    }

    // Builds the starting state for the default arena: two players on top of
    // the central platform, facing each other, each with a full quiver, in the
    // opening countdown.
    public static func initial(config: GameConfig, seed: UInt64) -> GameState {
        let p0 = PlayerState(
            pos: FixedVec(x: Fixed(config.spawnX0), y: Fixed(config.spawnY)),
            facing: 1,
            arrows: config.startingArrows
        )
        let p1 = PlayerState(
            pos: FixedVec(x: Fixed(config.spawnX1), y: Fixed(config.spawnY)),
            facing: -1,
            arrows: config.startingArrows
        )
        let capacity = config.startingArrows * 2
        let arrows = [ArrowState](repeating: .empty, count: capacity)
        return GameState(
            tick: 0,
            players: [p0, p1],
            arrows: arrows,
            rng: DeterministicRandom(seed: seed),
            phase: .countdown,
            phaseTimer: config.countdownTicks,
            scores: [0, 0],
            round: 0,
            winner: -1
        )
    }
}
