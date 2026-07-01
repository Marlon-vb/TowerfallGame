// ArrowState.swift
// Plain-data state for a single arrow. Arrows live in a fixed-capacity array in
// GameState so slot indices are stable (good for snapshots and hashing); an
// inactive slot is a free slot.
//
// pos is the arrow's point position (arrows are treated as a point for tile
// collision, which is exact while arrow speed stays below tileSize). dir is the
// fired aim direction, kept only so the renderer can orient a stuck arrow.

// Special arrow types (TowerFall-style). Raw values are part of the wire/state
// format; never reorder.
public enum ArrowKind: UInt8, Equatable {
    case normal = 0
    case bomb = 1    // explodes on impact, killing anyone in a radius (owner too)
    case laser = 2   // very fast, flies perfectly straight (no gravity)
    case drill = 3   // passes through tiles instead of sticking; limited life
    case feather = 4 // slow straight flier that wraps the screen; limited life
}

public struct ArrowState: Equatable, Hashable {
    public var pos: FixedVec
    public var vel: FixedVec
    public var active: Bool   // false == empty slot
    public var stuck: Bool    // true once embedded in a tile / resting (reclaimable)
    public var owner: Int8    // player index that fired it
    public var dir: UInt8     // fired direction, render-only orientation
    public var kind: UInt8    // ArrowKind raw value
    public var life: Int32    // ticks since fired (TTL for drill/feather)

    public init(
        pos: FixedVec = .zero,
        vel: FixedVec = .zero,
        active: Bool = false,
        stuck: Bool = false,
        owner: Int8 = -1,
        dir: UInt8 = 0,
        kind: UInt8 = 0,
        life: Int32 = 0
    ) {
        self.pos = pos
        self.vel = vel
        self.active = active
        self.stuck = stuck
        self.owner = owner
        self.dir = dir
        self.kind = kind
        self.life = life
    }

    public var arrowKind: ArrowKind { ArrowKind(rawValue: kind) ?? .normal }

    public static let empty = ArrowState()
}

// A treasure chest that spawns mid-round and grants special arrows to whoever
// reaches it first. Part of the deterministic state (rolls back like the rest).
public struct ChestState: Equatable {
    public var active: Bool      // visible and collectible
    public var pos: FixedVec     // point position (tile center)
    public var kind: UInt8       // ArrowKind raw value it grants
    public var spawnTimer: Int32 // playing-ticks until it appears (per round)

    public init(active: Bool = false, pos: FixedVec = .zero, kind: UInt8 = 0, spawnTimer: Int32 = 0) {
        self.active = active
        self.pos = pos
        self.kind = kind
        self.spawnTimer = spawnTimer
    }
}
