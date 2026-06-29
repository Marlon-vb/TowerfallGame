// GameScene.swift
// Renders the deterministic sim. SpriteKit ONLY draws state the sim produces;
// it never moves anything itself (no SKPhysics, no SKAction movement). The sim
// runs on a fixed 60 Hz timestep accumulated from frame time, and rendering
// interpolates between the previous and current sim state for smoothness.
//
// Coordinate mapping: the sim is y-down with origin at the top-left; the scene
// is y-up with origin at the bottom-left. So skY = worldHeight - simY. The only
// float usage is this render-time conversion, which is allowed.

import SpriteKit
import ArrowClashSim

final class GameScene: SKScene {
    private let config = GameConfig.default
    private let map = TileMap.defaultArena()
    private let input: InputBus

    private var current: GameState
    private var previous: GameState

    private let tickDuration: TimeInterval = 1.0 / 60.0
    private var accumulator: TimeInterval = 0
    private var lastTime: TimeInterval = 0

    private var playerNodes: [SKShapeNode] = []
    private var arrowNodes: [SKShapeNode] = []
    private var hud: SKLabelNode = SKLabelNode()

    private var worldWidthPx: Float { Float(map.cols * config.tileSize) }
    private var worldHeightPx: Float { Float(map.rows * config.tileSize) }

    private let playerColors: [SKColor] = [
        SKColor(red: 0.30, green: 0.75, blue: 1.00, alpha: 1.0),
        SKColor(red: 1.00, green: 0.45, blue: 0.40, alpha: 1.0),
    ]

    init(input: InputBus) {
        self.input = input
        let initial = GameState.initial(config: GameConfig.default, seed: 1)
        self.current = initial
        self.previous = initial
        let worldSize = CGSize(
            width: GameConfig.default.tileSize * TileMap.defaultArena().cols,
            height: GameConfig.default.tileSize * TileMap.defaultArena().rows
        )
        super.init(size: worldSize)
        self.scaleMode = .aspectFit
        self.anchorPoint = .zero
        self.backgroundColor = SKColor(red: 0.08, green: 0.09, blue: 0.12, alpha: 1.0)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func didMove(to view: SKView) {
        buildTiles()
        buildEntities()
        buildHUD()
    }

    // MARK: - Build

    private func buildTiles() {
        let ts = CGFloat(config.tileSize)
        for row in 0..<map.rows {
            for col in 0..<map.cols {
                guard map.isSolid(col: col, row: row) else { continue }
                let tile = SKSpriteNode(color: SKColor(red: 0.22, green: 0.24, blue: 0.30, alpha: 1.0),
                                        size: CGSize(width: ts, height: ts))
                let simCx = Float(col * config.tileSize) + Float(config.tileSize) / 2
                let simCy = Float(row * config.tileSize) + Float(config.tileSize) / 2
                tile.position = CGPoint(x: CGFloat(simCx), y: CGFloat(worldHeightPx - simCy))
                addChild(tile)
            }
        }
    }

    private func buildEntities() {
        let w = CGFloat(config.playerWidth.toFloat)
        let h = CGFloat(config.playerHeight.toFloat)
        for i in 0..<current.players.count {
            let node = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: 2)
            node.fillColor = playerColors[i % playerColors.count]
            node.strokeColor = .white
            node.lineWidth = 1
            addChild(node)
            playerNodes.append(node)
        }
        for _ in 0..<current.arrows.count {
            let node = SKShapeNode(rectOf: CGSize(width: 7, height: 2))
            node.fillColor = SKColor(red: 0.95, green: 0.9, blue: 0.5, alpha: 1.0)
            node.strokeColor = .clear
            node.isHidden = true
            addChild(node)
            arrowNodes.append(node)
        }
    }

    private func buildHUD() {
        hud.fontName = "Menlo-Bold"
        hud.fontSize = 10
        hud.fontColor = .white
        hud.horizontalAlignmentMode = .left
        hud.verticalAlignmentMode = .top
        hud.position = CGPoint(x: 6, y: CGFloat(worldHeightPx) - 4)
        addChild(hud)
    }

    // MARK: - Loop

    override func update(_ currentTime: TimeInterval) {
        if lastTime == 0 { lastTime = currentTime }
        var frameDelta = currentTime - lastTime
        lastTime = currentTime
        if frameDelta > 0.25 { frameDelta = 0.25 } // avoid spiral after a stall

        accumulator += frameDelta
        while accumulator >= tickDuration {
            previous = current
            let command = input.consumeForTick()
            // Single player for Phase 1: player 1 is an idle dummy.
            Simulation.tick(state: &current, inputs: [command, .neutral], map: map, config: config)
            accumulator -= tickDuration
        }

        let alpha = Float(accumulator / tickDuration)
        renderInterpolated(alpha: alpha)
    }

    // MARK: - Render

    private func renderInterpolated(alpha: Float) {
        let halfW = config.playerWidth.toFloat / 2
        let halfH = config.playerHeight.toFloat / 2

        for i in 0..<playerNodes.count {
            let pPrev = previous.players[i]
            let pCur = current.players[i]
            let cx = interp(pPrev.pos.x.toFloat + halfW, pCur.pos.x.toFloat + halfW, alpha, worldWidthPx)
            let cy = interp(pPrev.pos.y.toFloat + halfH, pCur.pos.y.toFloat + halfH, alpha, worldHeightPx)
            playerNodes[i].position = skPoint(cx, cy)
        }

        for a in 0..<arrowNodes.count {
            let cur = current.arrows[a]
            let node = arrowNodes[a]
            if !cur.active {
                node.isHidden = true
                continue
            }
            node.isHidden = false
            let prev = previous.arrows[a]
            let cx: Float
            let cy: Float
            if prev.active {
                cx = interp(prev.pos.x.toFloat, cur.pos.x.toFloat, alpha, worldWidthPx)
                cy = interp(prev.pos.y.toFloat, cur.pos.y.toFloat, alpha, worldHeightPx)
            } else {
                cx = cur.pos.x.toFloat
                cy = cur.pos.y.toFloat
            }
            node.position = skPoint(cx, cy)
            node.zRotation = arrowRotation(cur)
        }

        hud.text = "Arrows: \(current.players[0].arrows)/\(config.startingArrows)"
    }

    // sim point (y-down) -> scene point (y-up)
    private func skPoint(_ simX: Float, _ simY: Float) -> CGPoint {
        return CGPoint(x: CGFloat(simX), y: CGFloat(worldHeightPx - simY))
    }

    // Linear interpolation that snaps instead of interpolating across a wrap seam.
    private func interp(_ from: Float, _ to: Float, _ t: Float, _ wrap: Float) -> Float {
        let delta = to - from
        if abs(delta) > wrap * 0.5 { return to }
        return from + delta * t
    }

    // Orientation for an arrow. Flying arrows point along velocity; stuck arrows
    // keep the fired direction. Negate Y because the scene is y-up.
    private func arrowRotation(_ arrow: ArrowState) -> CGFloat {
        if !arrow.stuck && (arrow.vel.x.raw != 0 || arrow.vel.y.raw != 0) {
            return CGFloat(atan2(Double(-arrow.vel.y.toFloat), Double(arrow.vel.x.toFloat)))
        }
        let angle = Float(arrow.dir) / 256.0 * 2.0 * .pi
        return CGFloat(-angle)
    }
}
