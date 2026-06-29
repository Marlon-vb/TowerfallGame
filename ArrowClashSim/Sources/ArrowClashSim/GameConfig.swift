// GameConfig.swift
// Single place for all tunable gameplay constants so feel is easy to iterate.
// Everything is in Q16.16 fixed-point pixels and pixels-per-tick (60 Hz tick).
//
// These are the proposed defaults. They are meant to be tuned in later phases;
// nothing reads magic numbers anywhere else in the sim.
//
// Units:
//   position / size : pixels
//   velocity        : pixels per tick
//   acceleration    : pixels per tick^2
//   timers          : ticks (60 ticks == 1 second)
//
// Important constraint for the swept collision: per-axis displacement in a
// single tick must stay below tileSize so a moving AABB can enter at most one
// new tile per axis. dashSpeed (7) and maxFallSpeed (8) are both below
// tileSize (16), so this holds. If you raise a speed above tileSize, the
// collision resolver needs sub-stepping.

public struct GameConfig: Equatable {
    public var ticksPerSecond: Int

    // World / collision geometry.
    public var tileSize: Int
    public var playerWidth: Fixed
    public var playerHeight: Fixed

    // Horizontal movement.
    public var runAccel: Fixed
    public var airAccel: Fixed
    public var runMaxSpeed: Fixed
    public var groundFriction: Fixed
    public var airFriction: Fixed

    // Vertical movement.
    public var gravity: Fixed
    public var maxFallSpeed: Fixed
    public var jumpSpeed: Fixed
    public var jumpCutMultiplier: Fixed  // applied to upward velocity when jump released early
    public var coyoteTicks: Int32
    public var jumpBufferTicks: Int32

    // Dash.
    public var dashSpeed: Fixed
    public var dashDurationTicks: Int32
    public var dashCooldownTicks: Int32

    // Combat (used from Phase 1 onward, declared here so config is one file).
    public var startingArrows: Int
    public var arrowSpeed: Fixed        // initial speed of a fired arrow, px/tick
    public var arrowGravity: Fixed      // light gravity so arrows arc, px/tick^2
    public var arrowMaxFallSpeed: Fixed // terminal fall speed for arrows
    public var arrowSpawnOffset: Fixed  // distance from player center to spawn the arrow

    // Spawn points for the default arena (see TileMap.defaultArena).
    // Both spawn on top of the central platform.
    public var spawnX0: Int
    public var spawnX1: Int
    public var spawnY: Int

    public init(
        ticksPerSecond: Int = 60,
        tileSize: Int = 16,
        playerWidth: Fixed = Fixed(10),
        playerHeight: Fixed = Fixed(14),
        runAccel: Fixed = Fixed(numerator: 3, denominator: 5),    // 0.6
        airAccel: Fixed = Fixed(numerator: 2, denominator: 5),    // 0.4
        runMaxSpeed: Fixed = Fixed(3),                            // 3.0
        groundFriction: Fixed = Fixed(numerator: 4, denominator: 5), // 0.8
        airFriction: Fixed = Fixed(numerator: 1, denominator: 5),    // 0.2
        gravity: Fixed = Fixed(numerator: 1, denominator: 2),     // 0.5
        maxFallSpeed: Fixed = Fixed(8),                           // 8.0
        jumpSpeed: Fixed = Fixed(7),                              // 7.0  (apex ~3 tiles)
        jumpCutMultiplier: Fixed = Fixed(numerator: 1, denominator: 2), // 0.5
        coyoteTicks: Int32 = 6,                                   // ~0.1s
        jumpBufferTicks: Int32 = 6,                               // ~0.1s
        dashSpeed: Fixed = Fixed(7),                              // 7.0
        dashDurationTicks: Int32 = 8,                             // ~0.13s
        dashCooldownTicks: Int32 = 30,                            // ~0.5s
        startingArrows: Int = 3,
        arrowSpeed: Fixed = Fixed(7),                            // 7.0
        arrowGravity: Fixed = Fixed(numerator: 1, denominator: 5), // 0.2
        arrowMaxFallSpeed: Fixed = Fixed(8),                     // 8.0
        arrowSpawnOffset: Fixed = Fixed(8),                      // 8 px ahead of center
        spawnX0: Int = 112,
        spawnX1: Int = 192,
        spawnY: Int = 82
    ) {
        self.ticksPerSecond = ticksPerSecond
        self.tileSize = tileSize
        self.playerWidth = playerWidth
        self.playerHeight = playerHeight
        self.runAccel = runAccel
        self.airAccel = airAccel
        self.runMaxSpeed = runMaxSpeed
        self.groundFriction = groundFriction
        self.airFriction = airFriction
        self.gravity = gravity
        self.maxFallSpeed = maxFallSpeed
        self.jumpSpeed = jumpSpeed
        self.jumpCutMultiplier = jumpCutMultiplier
        self.coyoteTicks = coyoteTicks
        self.jumpBufferTicks = jumpBufferTicks
        self.dashSpeed = dashSpeed
        self.dashDurationTicks = dashDurationTicks
        self.dashCooldownTicks = dashCooldownTicks
        self.startingArrows = startingArrows
        self.arrowSpeed = arrowSpeed
        self.arrowGravity = arrowGravity
        self.arrowMaxFallSpeed = arrowMaxFallSpeed
        self.arrowSpawnOffset = arrowSpawnOffset
        self.spawnX0 = spawnX0
        self.spawnX1 = spawnX1
        self.spawnY = spawnY
    }

    public static let `default` = GameConfig()
}
