// GameState.swift
// The full mutable simulation state. Plain value types only, no references, so
// a copy is a snapshot and assignment is a restore. This is what rollback
// saves and rewinds.
//
// players is a fixed two-element array, always iterated in index order (0 then
// 1) so iteration order is deterministic.

public struct GameState: Equatable {
    public var tick: UInt32
    public var players: [PlayerState]
    // Fixed-capacity arrow pool (startingArrows per player). Stable indices.
    public var arrows: [ArrowState]
    public var rng: DeterministicRandom

    public init(tick: UInt32, players: [PlayerState], arrows: [ArrowState], rng: DeterministicRandom) {
        self.tick = tick
        self.players = players
        self.arrows = arrows
        self.rng = rng
    }

    // Builds the starting state for the default arena: two players on top of
    // the central platform, facing each other, each with a full quiver.
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
        return GameState(tick: 0, players: [p0, p1], arrows: arrows, rng: DeterministicRandom(seed: seed))
    }
}
