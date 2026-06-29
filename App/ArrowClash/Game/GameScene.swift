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
    private let map: TileMap
    private let tileColor: SKColor
    private let input: InputBus
    private let driver: SceneDriver

    private let tickDuration: TimeInterval = 1.0 / 60.0
    private var accumulator: TimeInterval = 0
    private var lastTime: TimeInterval = 0

    private let world = SKNode() // everything that can shake
    private var playerNodes: [SKShapeNode] = []
    private var arrowNodes: [SKShapeNode] = []
    private var hud = SKLabelNode()
    private var scoreLabel = SKLabelNode()
    private var centerLabel = SKLabelNode()
    private var flash = SKSpriteNode()

    // Fired once when the match ends: (localWon, localKills, totalRounds).
    var onMatchEnd: ((Bool, Int, Int) -> Void)?
    private var matchEndFired = false

    // Cosmetic colors per player slot (skin = body, trail = arrow color).
    private let skinColors: [SKColor]
    private let trailColors: [SKColor]

    private var worldWidthPx: Float { Float(map.cols * config.tileSize) }
    private var worldHeightPx: Float { Float(map.rows * config.tileSize) }

    private let playerColors: [SKColor] = [
        SKColor(red: 0.30, green: 0.75, blue: 1.00, alpha: 1.0),
        SKColor(red: 1.00, green: 0.45, blue: 0.40, alpha: 1.0),
    ]

    init(input: InputBus,
         driver: SceneDriver,
         map: MapDefinition = Maps.default,
         skinColors: [SKColor] = [SKColor(red: 0.30, green: 0.75, blue: 1.00, alpha: 1.0),
                                  SKColor(red: 1.00, green: 0.45, blue: 0.40, alpha: 1.0)],
         trailColors: [SKColor] = [.white, .white],
         tileColor: SKColor = SKColor(red: 0.22, green: 0.24, blue: 0.30, alpha: 1.0),
         bgColor: SKColor = SKColor(red: 0.08, green: 0.09, blue: 0.12, alpha: 1.0)) {
        self.input = input
        self.driver = driver
        self.map = map.tileMap()
        self.tileColor = tileColor
        self.skinColors = skinColors
        self.trailColors = trailColors
        let worldSize = CGSize(
            width: GameConfig.default.tileSize * map.cols,
            height: GameConfig.default.tileSize * map.rows
        )
        super.init(size: worldSize)
        self.scaleMode = .aspectFit
        self.anchorPoint = .zero
        self.backgroundColor = bgColor
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func didMove(to view: SKView) {
        addChild(world)
        buildTiles()
        buildEntities()
        buildHUD()
        buildFlash()
        AudioManager.shared.preload()
    }

    // MARK: - Build

    private func buildTiles() {
        let ts = CGFloat(config.tileSize)
        for row in 0..<map.rows {
            for col in 0..<map.cols where map.isSolid(col: col, row: row) {
                let tile = SKSpriteNode(color: tileColor, size: CGSize(width: ts, height: ts))
                let simCx = Float(col * config.tileSize) + Float(config.tileSize) / 2
                let simCy = Float(row * config.tileSize) + Float(config.tileSize) / 2
                tile.position = CGPoint(x: CGFloat(simCx), y: CGFloat(worldHeightPx - simCy))
                world.addChild(tile)
            }
        }
    }

    private func buildEntities() {
        let state = driver.renderStates().current
        let w = CGFloat(config.playerWidth.toFloat)
        let h = CGFloat(config.playerHeight.toFloat)
        for i in 0..<state.players.count {
            let node = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: 2)
            node.fillColor = i < skinColors.count ? skinColors[i] : playerColors[i % playerColors.count]
            node.strokeColor = (i == driver.localPlayer) ? .white : .clear
            node.lineWidth = 1
            world.addChild(node)
            playerNodes.append(node)
        }
        for _ in 0..<state.arrows.count {
            let node = SKShapeNode(rectOf: CGSize(width: 7, height: 2))
            node.fillColor = SKColor(red: 0.95, green: 0.9, blue: 0.5, alpha: 1.0)
            node.strokeColor = .clear
            node.isHidden = true
            world.addChild(node)
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

        scoreLabel.fontName = "Menlo-Bold"
        scoreLabel.fontSize = 14
        scoreLabel.fontColor = .white
        scoreLabel.horizontalAlignmentMode = .center
        scoreLabel.verticalAlignmentMode = .top
        scoreLabel.position = CGPoint(x: CGFloat(worldWidthPx) / 2, y: CGFloat(worldHeightPx) - 4)
        addChild(scoreLabel)

        centerLabel.fontName = "Menlo-Bold"
        centerLabel.fontSize = 22
        centerLabel.fontColor = .white
        centerLabel.horizontalAlignmentMode = .center
        centerLabel.verticalAlignmentMode = .center
        centerLabel.position = CGPoint(x: CGFloat(worldWidthPx) / 2, y: CGFloat(worldHeightPx) * 0.62)
        addChild(centerLabel)
    }

    private func buildFlash() {
        flash = SKSpriteNode(color: .white, size: CGSize(width: CGFloat(worldWidthPx), height: CGFloat(worldHeightPx)))
        flash.anchorPoint = .zero
        flash.position = .zero
        flash.alpha = 0
        flash.zPosition = 1000
        addChild(flash)
    }

    // MARK: - Loop

    override func update(_ currentTime: TimeInterval) {
        if lastTime == 0 { lastTime = currentTime }
        var frameDelta = currentTime - lastTime
        lastTime = currentTime
        if frameDelta > 0.25 { frameDelta = 0.25 }

        accumulator += frameDelta
        var didTick = false
        while accumulator >= tickDuration {
            driver.advance(localInput: input.consumeForTick())
            accumulator -= tickDuration
            didTick = true
        }

        if didTick {
            let states = driver.renderStates()
            detectEvents(previous: states.previous, current: states.current)
        }

        renderInterpolated(alpha: Float(accumulator / tickDuration))
    }

    // MARK: - Juice (render-only)

    // Compares the last tick's before/after states to fire sounds and effects.
    // Movement sounds are local-player only (those inputs aren't predicted, so
    // they don't flicker under rollback); death effects fire for either player.
    private func detectEvents(previous: GameState, current: GameState) {
        let me = driver.localPlayer

        let count = min(previous.players.count, current.players.count)
        for i in 0..<count {
            if previous.players[i].alive && !current.players[i].alive {
                onDeath(player: current.players[i])
            }
        }

        if me < count {
            let before = previous.players[me]
            let after = current.players[me]
            if before.dashActiveTimer == 0 && after.dashActiveTimer > 0 {
                AudioManager.shared.play("dash", on: self)
            }
            if before.onGround && !after.onGround && after.vel.y.raw < 0 {
                AudioManager.shared.play("jump", on: self)
            }
        }

        let arrowCount = min(previous.arrows.count, current.arrows.count)
        for i in 0..<arrowCount {
            if !previous.arrows[i].active && current.arrows[i].active && Int(current.arrows[i].owner) == me {
                AudioManager.shared.play("shoot", on: self)
            }
        }
    }

    private func onDeath(player: PlayerState) {
        AudioManager.shared.play("hit", on: self)
        shakeScreen(intensity: 7)
        triggerFlash()
        let cx = player.pos.x.toFloat + config.playerWidth.toFloat / 2
        let cy = player.pos.y.toFloat + config.playerHeight.toFloat / 2
        spawnDeathParticles(at: skPoint(cx, cy))
    }

    private func shakeScreen(intensity: CGFloat) {
        var steps: [SKAction] = []
        for _ in 0..<6 {
            let dx = CGFloat.random(in: -intensity...intensity)
            let dy = CGFloat.random(in: -intensity...intensity)
            steps.append(.move(to: CGPoint(x: dx, y: dy), duration: 0.02))
        }
        steps.append(.move(to: .zero, duration: 0.02))
        world.run(.sequence(steps))
    }

    private func triggerFlash() {
        flash.removeAllActions()
        flash.alpha = 0.5
        flash.run(.fadeOut(withDuration: 0.18))
    }

    private func spawnDeathParticles(at point: CGPoint) {
        for _ in 0..<14 {
            let p = SKShapeNode(rectOf: CGSize(width: 3, height: 3))
            p.fillColor = SKColor(red: 1.0, green: 0.85, blue: 0.4, alpha: 1.0)
            p.strokeColor = .clear
            p.position = point
            p.zPosition = 50
            world.addChild(p)
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let dist = CGFloat.random(in: 14...34)
            let move = SKAction.move(by: CGVector(dx: cos(angle) * dist, dy: sin(angle) * dist), duration: 0.4)
            move.timingMode = .easeOut
            let group = SKAction.group([move, .fadeOut(withDuration: 0.4)])
            p.run(.sequence([group, .removeFromParent()]))
        }
    }

    // MARK: - Render

    private func renderInterpolated(alpha: Float) {
        let (previous, current) = driver.renderStates()
        let halfW = config.playerWidth.toFloat / 2
        let halfH = config.playerHeight.toFloat / 2

        for i in 0..<playerNodes.count where i < current.players.count {
            let pPrev = previous.players[i]
            let pCur = current.players[i]
            playerNodes[i].isHidden = !pCur.alive
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
            let owner = Int(cur.owner)
            if owner >= 0 && owner < trailColors.count {
                node.fillColor = trailColors[owner]
            }
        }

        let me = driver.localPlayer
        if me < current.players.count {
            hud.text = "Arrows: \(current.players[me].arrows)/\(config.startingArrows)"
        }

        updateMatchLabels(current)
    }

    private func updateMatchLabels(_ state: GameState) {
        if state.scores.count >= 2 {
            scoreLabel.text = "\(state.scores[0])   -   \(state.scores[1])"
        }

        switch state.phase {
        case .countdown:
            let secondsLeft = Int((Double(state.phaseTimer) / 30.0).rounded(.up))
            centerLabel.text = secondsLeft > 0 ? "\(secondsLeft)" : "GO"
        case .playing:
            centerLabel.text = ""
        case .roundOver:
            centerLabel.text = "ROUND OVER"
        case .matchOver:
            let me = driver.localPlayer
            let localWon = state.winner == Int8(me)
            centerLabel.text = localWon ? "YOU WIN" : "YOU LOSE"
            if !matchEndFired {
                matchEndFired = true
                let kills = me < state.scores.count ? state.scores[me] : 0
                let rounds = state.scores.reduce(0, +)
                onMatchEnd?(localWon, kills, rounds)
            }
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
