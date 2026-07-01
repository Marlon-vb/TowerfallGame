// PlayerState.swift
// Plain-data per-player state. Value type so the whole GameState copies and
// restores cheaply for rollback.
//
// pos is the minimum corner (left, top) of the player's AABB, in fixed-point
// pixels. The AABB size comes from GameConfig (playerWidth/playerHeight).

public struct PlayerState: Equatable, Hashable {
    public var pos: FixedVec
    public var vel: FixedVec
    public var facing: Int8            // -1 left, +1 right

    public var onGround: Bool
    public var coyoteTimer: Int32      // ticks since leaving ground during which a jump is still allowed
    public var jumpBufferTimer: Int32  // ticks remaining of a buffered jump press
    public var dashActiveTimer: Int32  // > 0 while a dash is in progress
    public var dashCooldownTimer: Int32 // > 0 while dash is on cooldown

    public var prevButtons: UInt8      // last tick's buttons, for press/release edge detection

    public var arrows: Int             // normal arrows currently in the quiver
    public var alive: Bool             // false once hit; one-hit kill

    // Special arrows (from chests or picked-up special arrows). One kind held
    // at a time; special shots fire before normal ones.
    public var specialKind: UInt8      // ArrowKind raw value (0 == none)
    public var specialCount: Int32     // special arrows remaining

    public init(
        pos: FixedVec,
        vel: FixedVec = .zero,
        facing: Int8 = 1,
        onGround: Bool = false,
        coyoteTimer: Int32 = 0,
        jumpBufferTimer: Int32 = 0,
        dashActiveTimer: Int32 = 0,
        dashCooldownTimer: Int32 = 0,
        prevButtons: UInt8 = 0,
        arrows: Int = 0,
        alive: Bool = true,
        specialKind: UInt8 = 0,
        specialCount: Int32 = 0
    ) {
        self.pos = pos
        self.vel = vel
        self.facing = facing
        self.onGround = onGround
        self.coyoteTimer = coyoteTimer
        self.jumpBufferTimer = jumpBufferTimer
        self.dashActiveTimer = dashActiveTimer
        self.dashCooldownTimer = dashCooldownTimer
        self.prevButtons = prevButtons
        self.arrows = arrows
        self.alive = alive
        self.specialKind = specialKind
        self.specialCount = specialCount
    }
}
