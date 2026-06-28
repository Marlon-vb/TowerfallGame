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
        let count = state.players.count
        var i = 0
        while i < count {
            step(player: &state.players[i], input: inputs[i], map: map, config: config)
            i += 1
        }
        state.tick &+= 1
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
}
