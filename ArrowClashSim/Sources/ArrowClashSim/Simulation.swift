// Simulation.swift
// The deterministic 60 Hz tick. Advances the state purely as a function of
// (previous state, both players' inputs, static map, config). No floats, no
// time, no unseeded randomness, no reference types, fixed iteration order.
//
// Phase 0 scope: run, jump (with coyote time + jump buffer + jump cut), dash
// (with cooldown), gravity, swept-AABB collision against the static tile grid,
// and both-axis screen wrapping. Arrows, shooting, pickups and death are later
// phases and are intentionally not implemented here.

public enum Simulation {

    // Advances `state` by exactly one tick. `inputs` must have one entry per
    // player, in player-index order.
    public static func tick(
        state: inout GameState,
        inputs: [InputCommand],
        map: TileMap,
        config: GameConfig
    ) {
        switch state.phase {
        case .countdown:
            advanceFrozen(state: &state, map: map, config: config)
            state.phaseTimer -= 1
            if state.phaseTimer <= 0 {
                state.phase = .playing
            }
        case .playing:
            advancePlaying(state: &state, inputs: inputs, map: map, config: config)
            resolveDeaths(state: &state, config: config)
        case .roundOver:
            advanceFrozen(state: &state, map: map, config: config)
            state.phaseTimer -= 1
            if state.phaseTimer <= 0 {
                advanceRoundOrMatch(state: &state, config: config)
            }
        case .matchOver:
            break // fully frozen
        }
        state.tick &+= 1
    }

    // Live gameplay: step players with their inputs, then arrows.
    private static func advancePlaying(
        state: inout GameState,
        inputs: [InputCommand],
        map: TileMap,
        config: GameConfig
    ) {
        let count = state.players.count

        // Capture each player's previous buttons before stepping, because step
        // overwrites prevButtons and the arrow shoot edge needs the old value.
        var priorButtons = [UInt8](repeating: 0, count: count)
        var i = 0
        while i < count {
            priorButtons[i] = state.players[i].prevButtons
            i += 1
        }

        i = 0
        while i < count {
            step(player: &state.players[i], input: inputs[i], map: map, config: config)
            i += 1
        }

        updateArrows(state: &state, inputs: inputs, priorButtons: priorButtons, map: map, config: config)
    }

    // Countdown / round-over: players are frozen but gravity still settles them
    // onto the ground. Inputs and arrows are ignored.
    private static func advanceFrozen(
        state: inout GameState,
        map: TileMap,
        config: GameConfig
    ) {
        var i = 0
        while i < state.players.count {
            step(player: &state.players[i], input: .neutral, map: map, config: config)
            i += 1
        }
    }

    // MARK: - Per-player step

    private static func step(
        player p: inout PlayerState,
        input: InputCommand,
        map: TileMap,
        config: GameConfig
    ) {
        let buttons = input.buttons.rawValue
        let prev = p.prevButtons

        let leftHeld  = (buttons & InputCommand.Buttons.left.rawValue) != 0
        let rightHeld = (buttons & InputCommand.Buttons.right.rawValue) != 0
        let jumpHeld  = (buttons & InputCommand.Buttons.jump.rawValue) != 0

        let jumpPressed = jumpHeld && (prev & InputCommand.Buttons.jump.rawValue) == 0
        let jumpReleased = !jumpHeld && (prev & InputCommand.Buttons.jump.rawValue) != 0
        let dashPressed = ((buttons & InputCommand.Buttons.dash.rawValue) != 0)
            && (prev & InputCommand.Buttons.dash.rawValue) == 0

        // 1. Dash timers. When an active dash ends this tick, start the cooldown.
        if p.dashActiveTimer > 0 {
            p.dashActiveTimer -= 1
            if p.dashActiveTimer == 0 {
                p.dashCooldownTimer = config.dashCooldownTicks
            }
        } else if p.dashCooldownTimer > 0 {
            p.dashCooldownTimer -= 1
        }

        let dashing = p.dashActiveTimer > 0

        // 2. Horizontal acceleration / friction (skipped while dashing, which
        //    locks horizontal velocity).
        if !dashing {
            let dir = (rightHeld ? 1 : 0) - (leftHeld ? 1 : 0)
            if dir != 0 {
                p.facing = dir > 0 ? 1 : -1
                let accel = p.onGround ? config.runAccel : config.airAccel
                p.vel.x += Fixed(dir) * accel
                p.vel.x = Fixed.clamp(p.vel.x, min: -config.runMaxSpeed, max: config.runMaxSpeed)
            } else {
                let friction = p.onGround ? config.groundFriction : config.airFriction
                p.vel.x = applyFriction(p.vel.x, amount: friction)
            }
        }

        // 3. Start a dash if requested and off cooldown. Dash direction comes
        //    from the held horizontal input, defaulting to facing. Horizontal
        //    dash only in v1 (note: 8-direction dash is a later option).
        if dashPressed && p.dashActiveTimer == 0 && p.dashCooldownTimer == 0 {
            let dashDir: Int
            if leftHeld && !rightHeld {
                dashDir = -1
            } else if rightHeld && !leftHeld {
                dashDir = 1
            } else {
                dashDir = Int(p.facing)
            }
            p.dashActiveTimer = config.dashDurationTicks
            p.vel.x = Fixed(dashDir) * config.dashSpeed
            p.vel.y = .zero
            p.facing = dashDir > 0 ? 1 : -1
        }

        let dashingNow = p.dashActiveTimer > 0

        // 4. Gravity (suppressed during a dash so it floats, TowerFall-style).
        if !dashingNow {
            p.vel.y += config.gravity
            if p.vel.y > config.maxFallSpeed {
                p.vel.y = config.maxFallSpeed
            }
        }

        // 5. Jump: buffer the press, then consume it if grounded or within the
        //    coyote window. Not allowed mid-dash.
        if jumpPressed {
            p.jumpBufferTimer = config.jumpBufferTicks
        }
        if p.jumpBufferTimer > 0 && !dashingNow && (p.onGround || p.coyoteTimer > 0) {
            p.vel.y = -config.jumpSpeed
            p.onGround = false
            p.coyoteTimer = 0
            p.jumpBufferTimer = 0
        }
        // Variable jump height: releasing jump while still rising cuts the rise.
        if jumpReleased && p.vel.y.raw < 0 {
            p.vel.y = p.vel.y * config.jumpCutMultiplier
        }

        // 6. Integrate position with swept-AABB collision, X then Y.
        p.onGround = false
        resolveX(&p, map: map, config: config)
        resolveY(&p, map: map, config: config)

        // 7. Coyote time and jump-buffer decay.
        if p.onGround {
            p.coyoteTimer = config.coyoteTicks
        } else if p.coyoteTimer > 0 {
            p.coyoteTimer -= 1
        }
        if p.jumpBufferTimer > 0 {
            p.jumpBufferTimer -= 1
        }

        // 8. Wrap on both axes (edges are open).
        wrap(&p, map: map, config: config)

        // 9. Remember inputs for next-tick edge detection.
        p.prevButtons = buttons
    }

    // MARK: - Friction

    private static func applyFriction(_ velocity: Fixed, amount: Fixed) -> Fixed {
        if velocity.raw > 0 {
            let reduced = velocity - amount
            return reduced.raw < 0 ? .zero : reduced
        } else if velocity.raw < 0 {
            let reduced = velocity + amount
            return reduced.raw > 0 ? .zero : reduced
        }
        return .zero
    }

    // MARK: - Collision
    //
    // Per-axis resolution. Because per-tick displacement is guaranteed below
    // tileSize (see GameConfig), a moving AABB enters at most one new tile per
    // axis, so checking the single leading tile column/row and snapping to its
    // boundary is exact. If a speed ever exceeds tileSize this must sub-step.

    private static func resolveX(_ p: inout PlayerState, map: TileMap, config: GameConfig) {
        let ts = config.tileSize
        let w = config.playerWidth
        let h = config.playerHeight

        p.pos.x += p.vel.x

        let top = p.pos.y
        let bottom = p.pos.y + h
        let rowMin = TileMap.tileIndex(top, tileSize: ts)
        let rowMax = TileMap.tileIndex(Fixed(raw: bottom.raw - 1), tileSize: ts)

        if p.vel.x.raw > 0 {
            let right = p.pos.x + w
            let col = TileMap.tileIndex(Fixed(raw: right.raw - 1), tileSize: ts)
            var row = rowMin
            while row <= rowMax {
                if map.isSolid(col: col, row: row) {
                    p.pos.x = Fixed(col * ts) - w
                    p.vel.x = .zero
                    break
                }
                row += 1
            }
        } else if p.vel.x.raw < 0 {
            let col = TileMap.tileIndex(p.pos.x, tileSize: ts)
            var row = rowMin
            while row <= rowMax {
                if map.isSolid(col: col, row: row) {
                    p.pos.x = Fixed((col + 1) * ts)
                    p.vel.x = .zero
                    break
                }
                row += 1
            }
        }
    }

    private static func resolveY(_ p: inout PlayerState, map: TileMap, config: GameConfig) {
        let ts = config.tileSize
        let w = config.playerWidth
        let h = config.playerHeight

        p.pos.y += p.vel.y

        let left = p.pos.x
        let right = p.pos.x + w
        let colMin = TileMap.tileIndex(left, tileSize: ts)
        let colMax = TileMap.tileIndex(Fixed(raw: right.raw - 1), tileSize: ts)

        if p.vel.y.raw > 0 {
            let bottom = p.pos.y + h
            let row = TileMap.tileIndex(Fixed(raw: bottom.raw - 1), tileSize: ts)
            var col = colMin
            while col <= colMax {
                if map.isSolid(col: col, row: row) {
                    p.pos.y = Fixed(row * ts) - h
                    p.vel.y = .zero
                    p.onGround = true
                    break
                }
                col += 1
            }
        } else if p.vel.y.raw < 0 {
            let row = TileMap.tileIndex(p.pos.y, tileSize: ts)
            var col = colMin
            while col <= colMax {
                if map.isSolid(col: col, row: row) {
                    p.pos.y = Fixed((row + 1) * ts)
                    p.vel.y = .zero
                    break
                }
                col += 1
            }
        }
    }

    // MARK: - Wrapping

    private static func wrap(_ p: inout PlayerState, map: TileMap, config: GameConfig) {
        let worldW = Fixed(map.cols * config.tileSize)
        let worldH = Fixed(map.rows * config.tileSize)
        let halfW = config.playerWidth / Fixed(2)
        let halfH = config.playerHeight / Fixed(2)

        // Wrap based on the AABB center crossing an edge.
        let centerX = p.pos.x + halfW
        if centerX.raw < 0 {
            p.pos.x += worldW
        } else if centerX.raw >= worldW.raw {
            p.pos.x -= worldW
        }

        let centerY = p.pos.y + halfH
        if centerY.raw < 0 {
            p.pos.y += worldH
        } else if centerY.raw >= worldH.raw {
            p.pos.y -= worldH
        }
    }

    // MARK: - Arrows
    //
    // Order: spawn newly fired arrows, move flying arrows (sticking on tile
    // contact), then reclaim settled arrows the players walk over. Spawning
    // before moving means a freshly fired arrow is never stuck on its spawn
    // tick, so it cannot be reclaimed instantly by its own shooter.

    private static func updateArrows(
        state: inout GameState,
        inputs: [InputCommand],
        priorButtons: [UInt8],
        map: TileMap,
        config: GameConfig
    ) {
        let shootBit = InputCommand.Buttons.shoot.rawValue

        // 1. Shoot (on press edge, if the quiver has an arrow and a slot is free).
        var i = 0
        while i < state.players.count {
            let buttons = inputs[i].buttons.rawValue
            let shootPressed = (buttons & shootBit) != 0 && (priorButtons[i] & shootBit) == 0
            if shootPressed && state.players[i].arrows > 0 {
                if let slot = freeArrowSlot(state.arrows) {
                    let p = state.players[i]
                    let center = FixedVec(
                        x: p.pos.x + config.playerWidth / Fixed(2),
                        y: p.pos.y + config.playerHeight / Fixed(2)
                    )
                    let dir = inputs[i].aim
                    let unit = AimTable.unit(dir)
                    let spawn = FixedVec(
                        x: center.x + unit.x * config.arrowSpawnOffset,
                        y: center.y + unit.y * config.arrowSpawnOffset
                    )
                    state.arrows[slot] = ArrowState(
                        pos: spawn,
                        vel: FixedVec(x: unit.x * config.arrowSpeed, y: unit.y * config.arrowSpeed),
                        active: true,
                        stuck: false,
                        owner: Int8(i),
                        dir: dir
                    )
                    state.players[i].arrows -= 1
                }
            }
            i += 1
        }

        // 2. Move flying arrows. Point vs tile; stick on contact.
        var a = 0
        while a < state.arrows.count {
            if state.arrows[a].active && !state.arrows[a].stuck {
                stepArrow(&state.arrows[a], map: map, config: config)
            }
            a += 1
        }

        // 3. Reclaim settled arrows. A player overlapping a stuck arrow picks it
        //    up if their quiver is not full. Players checked in index order.
        a = 0
        while a < state.arrows.count {
            if state.arrows[a].active && state.arrows[a].stuck {
                var pi = 0
                while pi < state.players.count {
                    if state.players[pi].arrows < config.startingArrows
                        && pointInPlayer(state.arrows[a].pos, player: state.players[pi], config: config) {
                        state.players[pi].arrows += 1
                        state.arrows[a] = .empty
                        break
                    }
                    pi += 1
                }
            }
            a += 1
        }
    }

    private static func freeArrowSlot(_ arrows: [ArrowState]) -> Int? {
        var a = 0
        while a < arrows.count {
            if !arrows[a].active { return a }
            a += 1
        }
        return nil
    }

    private static func stepArrow(_ arrow: inout ArrowState, map: TileMap, config: GameConfig) {
        // Gravity (light arc).
        arrow.vel.y += config.arrowGravity
        if arrow.vel.y > config.arrowMaxFallSpeed {
            arrow.vel.y = config.arrowMaxFallSpeed
        }

        let previous = arrow.pos
        arrow.pos = FixedVec(x: arrow.pos.x + arrow.vel.x, y: arrow.pos.y + arrow.vel.y)

        // Point collision: if the new position is inside a solid tile, stick at
        // the pre-move position so the arrow rests against the surface. Valid
        // while arrow speed stays below tileSize (see GameConfig).
        let col = TileMap.tileIndex(arrow.pos.x, tileSize: config.tileSize)
        let row = TileMap.tileIndex(arrow.pos.y, tileSize: config.tileSize)
        if map.isSolid(col: col, row: row) {
            arrow.pos = previous
            arrow.vel = .zero
            arrow.stuck = true
            return
        }

        // Wrap on both axes, like players.
        let worldW = Fixed(map.cols * config.tileSize)
        let worldH = Fixed(map.rows * config.tileSize)
        if arrow.pos.x.raw < 0 { arrow.pos.x += worldW }
        else if arrow.pos.x.raw >= worldW.raw { arrow.pos.x -= worldW }
        if arrow.pos.y.raw < 0 { arrow.pos.y += worldH }
        else if arrow.pos.y.raw >= worldH.raw { arrow.pos.y -= worldH }
    }

    private static func pointInPlayer(_ point: FixedVec, player p: PlayerState, config: GameConfig) -> Bool {
        let left = p.pos.x
        let right = p.pos.x + config.playerWidth
        let top = p.pos.y
        let bottom = p.pos.y + config.playerHeight
        return point.x.raw >= left.raw && point.x.raw < right.raw
            && point.y.raw >= top.raw && point.y.raw < bottom.raw
    }

    // MARK: - Death and round resolution
    //
    // One-hit kill: a flying arrow that overlaps a player (other than its owner)
    // kills that player; a player who descends onto another's head stomps and
    // kills them. When a death occurs the round ends: the survivor (if exactly
    // one) scores. A double kill scores for no one.

    private static func resolveDeaths(state: inout GameState, config: GameConfig) {
        // Arrows.
        var a = 0
        while a < state.arrows.count {
            if state.arrows[a].active && !state.arrows[a].stuck {
                var pi = 0
                while pi < state.players.count {
                    if state.players[pi].alive
                        && Int8(pi) != state.arrows[a].owner
                        && pointInPlayer(state.arrows[a].pos, player: state.players[pi], config: config) {
                        state.players[pi].alive = false
                        state.arrows[a].active = false
                    }
                    pi += 1
                }
            }
            a += 1
        }

        // Stomp (exactly two players in v1).
        if state.players.count == 2 && state.players[0].alive && state.players[1].alive {
            if aabbOverlap(state.players[0], state.players[1], config: config) {
                let c0 = state.players[0].pos.y + config.playerHeight / Fixed(2)
                let c1 = state.players[1].pos.y + config.playerHeight / Fixed(2)
                // Upper player (smaller y) descending onto the other stomps it.
                if c0.raw < c1.raw && state.players[0].vel.y.raw > 0 {
                    state.players[1].alive = false
                    state.players[0].vel.y = -config.stompBounceSpeed
                } else if c1.raw < c0.raw && state.players[1].vel.y.raw > 0 {
                    state.players[0].alive = false
                    state.players[1].vel.y = -config.stompBounceSpeed
                }
            }
        }

        // Did anyone die? End the round if so.
        var aliveCount = 0
        var lastAlive = -1
        var pi = 0
        while pi < state.players.count {
            if state.players[pi].alive {
                aliveCount += 1
                lastAlive = pi
            }
            pi += 1
        }

        if aliveCount < state.players.count {
            if aliveCount == 1 {
                state.scores[lastAlive] += 1
            }
            // aliveCount == 0 is a double kill: no score.
            state.phase = .roundOver
            state.phaseTimer = config.roundOverTicks
        }
    }

    private static func aabbOverlap(_ a: PlayerState, _ b: PlayerState, config: GameConfig) -> Bool {
        let aLeft = a.pos.x.raw, aRight = (a.pos.x + config.playerWidth).raw
        let aTop = a.pos.y.raw, aBottom = (a.pos.y + config.playerHeight).raw
        let bLeft = b.pos.x.raw, bRight = (b.pos.x + config.playerWidth).raw
        let bTop = b.pos.y.raw, bBottom = (b.pos.y + config.playerHeight).raw
        return aLeft < bRight && aRight > bLeft && aTop < bBottom && aBottom > bTop
    }

    private static func advanceRoundOrMatch(state: inout GameState, config: GameConfig) {
        if state.scores[0] >= config.roundsToWin || state.scores[1] >= config.roundsToWin {
            state.phase = .matchOver
            state.winner = state.scores[0] >= config.roundsToWin ? 0 : 1
        } else {
            state.round += 1
            resetRound(state: &state, config: config)
            state.phase = .countdown
            state.phaseTimer = config.countdownTicks
        }
    }

    // Resets positions, arrows and quivers for a new round. Scores, round index,
    // and the rng carry over.
    private static func resetRound(state: inout GameState, config: GameConfig) {
        let spawns = [config.spawnX0, config.spawnX1]
        let facings: [Int8] = [1, -1]
        var i = 0
        while i < state.players.count {
            let x = i < spawns.count ? spawns[i] : config.spawnX0
            let facing = i < facings.count ? facings[i] : 1
            state.players[i] = PlayerState(
                pos: FixedVec(x: Fixed(x), y: Fixed(config.spawnY)),
                facing: facing,
                arrows: config.startingArrows
            )
            i += 1
        }
        var a = 0
        while a < state.arrows.count {
            state.arrows[a] = .empty
            a += 1
        }
    }
}
