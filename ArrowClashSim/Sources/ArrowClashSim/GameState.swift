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

    // Per-match constant spawn points (from the chosen map), carried so round
    // resets are self-contained inside the tick function.
    public var spawns: [FixedVec]

    public init(
        tick: UInt32,
        players: [PlayerState],
        arrows: [ArrowState],
        rng: DeterministicRandom,
        phase: MatchPhase,
        phaseTimer: Int32,
        scores: [Int],
        round: Int,
        winner: Int8,
        spawns: [FixedVec]
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
        self.spawns = spawns
    }

    // Starting state for a specific map: players on its spawn points, facing
    // each other, full quivers, opening countdown.
    public static func initial(map: MapDefinition, config: GameConfig, seed: UInt64) -> GameState {
        let spawnVecs = map.spawns.map { FixedVec(x: Fixed($0.x), y: Fixed($0.y)) }
        var players: [PlayerState] = []
        for (i, sp) in spawnVecs.enumerated() {
            players.append(PlayerState(pos: sp, facing: i == 0 ? 1 : -1, arrows: config.startingArrows))
        }
        let capacity = config.startingArrows * max(players.count, 1)
        let arrows = [ArrowState](repeating: .empty, count: capacity)
        return GameState(
            tick: 0,
            players: players,
            arrows: arrows,
            rng: DeterministicRandom(seed: seed),
            phase: .countdown,
            phaseTimer: config.countdownTicks,
            scores: [Int](repeating: 0, count: players.count),
            round: 0,
            winner: -1,
            spawns: spawnVecs
        )
    }

    // Convenience: the default arena. Kept so existing call sites/tests work.
    public static func initial(config: GameConfig, seed: UInt64) -> GameState {
        return initial(map: Maps.default, config: config, seed: seed)
    }
}
