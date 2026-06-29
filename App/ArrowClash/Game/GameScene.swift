// GameScene.swift
// Renders the deterministic sim. SpriteKit ONLY draws state the sim produces;
// it never moves anything itself (no SKPhysics, no SKAction movement). A
// SceneDriver advances the game one fixed 60 Hz tick at a time; rendering
// interpolates between the previous and current state for smoothness.
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
    private let driver: SceneDriver

    private let tickDuration: TimeInterval = 1.0 / 60.0
    private var accumulator: TimeInterval = 0
    private var lastTime: TimeInterval = 0

    private var playerNodes: [SKShapeNode] = []
    private var arrowNodes: [SKShapeNode] = []
    private var hud = SKLabelNode()

    private var worldWidthPx: Float { Float(map.cols * config.tileSize) }
    private var worldHeightPx: Float { Float(map.rows * config.tileSize) }

    private let playerColors: [SKColor] = [
        SKColor(red: 0.30, green: 0.75, blue: 1.00, alpha: 1.0),
        SKColor(red: 1.00, green: 0.45, blue: 0.40, alpha: 1.0),
    ]

    init(input: InputBus, driver: SceneDriver) {
        self.input = input
        self.driver = driver
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
            for col in 0..<map.cols where map.isSolid(col: col, row: row) {
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
        let state = driver.renderStates().current
        let w = CGFloat(config.playerWidth.toFloat)
        let h = CGFloat(config.playerHeight.toFloat)
        for i in 0..<state.players.count {
            let node = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: 2)
            node.fillColor = playerColors[i % playerColors.count]
            node.strokeColor = (i == driver.localPlayer) ? .white : .clear
            node.lineWidth = 1
            addChild(node)
            playerNodes.append(node)
        }
        for _ in 0..<state.arrows.count {
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
        if frameDelta > 0.25 { frameDelta = 0.25 }

        accumulator += frameDelta
        while accumulator >= tickDuration {
            driver.advance(localInput: input.consumeForTick())
            accumulator -= tickDuration
        }

        renderInterpolated(alpha: Float(accumulator / tickDuration))
    }

    // MARK: - Render

    private func renderInterpolated(alpha: Float) {
        let (previous, current) = driver.renderStates()
        let halfW = config.playerWidth.toFloat / 2
        let halfH = config.playerHeight.toFloat / 2

        for i in 0..<playerNodes.count where i < current.players.count {
            let pPrev = previous.players[i]
            let pCur = current.players[i]
            let cx = interp(pPrev.pos.x.toFloat + halfW, pCur.pos.x.toFloat + halfW, alpha, worldWidthPx)
            let cy = interp(pPrev.pos.y.toFloat + halfH, pCur.pos.y.toFloat + halfH, alpha, worldHeightPx)
            playerNodes[i].position = skPoint(cx, cy)
        }

        for a in 0..<arrowNodes.count where a < current.arrows.count {
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

        let me = driver.localPlayer
        if me < current.players.count {
            hud.text = "Arrows: \(current.players[me].arrows)/\(config.startingArrows)"
        }
    }

    private func skPoint(_ simX: Float, _ simY: Float) -> CGPoint {
        return CGPoint(x: CGFloat(simX), y: CGFloat(worldHeightPx - simY))
    }

    private func interp(_ from: Float, _ to: Float, _ t: Float, _ wrap: Float) -> Float {
        let delta = to - from
        if abs(delta) > wrap * 0.5 { return to }
        return from + delta * t
    }

    private func arrowRotation(_ arrow: ArrowState) -> CGFloat {
        if !arrow.stuck && (arrow.vel.x.raw != 0 || arrow.vel.y.raw != 0) {
            return CGFloat(atan2(Double(-arrow.vel.y.toFloat), Double(arrow.vel.x.toFloat)))
        }
        let angle = Float(arrow.dir) / 256.0 * 2.0 * .pi
        return CGFloat(-angle)
    }
}
