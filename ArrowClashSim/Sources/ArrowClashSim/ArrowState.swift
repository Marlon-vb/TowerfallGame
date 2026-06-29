// ArrowState.swift
// Plain-data state for a single arrow. Arrows live in a fixed-capacity array in
// GameState so slot indices are stable (good for snapshots and hashing); an
// inactive slot is a free slot.
//
// pos is the arrow's point position (arrows are treated as a point for tile
// collision, which is exact while arrow speed stays below tileSize). dir is the
// fired aim direction, kept only so the renderer can orient a stuck arrow.

public struct ArrowState: Equatable, Hashable {
    public var pos: FixedVec
    public var vel: FixedVec
    public var active: Bool   // false == empty slot
    public var stuck: Bool    // true once embedded in a tile / resting (reclaimable)
    public var owner: Int8    // player index that fired it
    public var dir: UInt8     // fired direction, render-only orientation

    public init(
        pos: FixedVec = .zero,
        vel: FixedVec = .zero,
        active: Bool = false,
        stuck: Bool = false,
        owner: Int8 = -1,
        dir: UInt8 = 0
    ) {
        self.pos = pos
        self.vel = vel
        self.active = active
        self.stuck = stuck
        self.owner = owner
        self.dir = dir
    }

    public static let empty = ArrowState()
}
