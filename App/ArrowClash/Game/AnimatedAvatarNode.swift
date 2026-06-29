// AnimatedAvatarNode.swift
// Composites a character from per-part layer sprites and animates them on a
// shared frame timeline. A base state (from sim) loops; one-shots (shoot) play
// once then revert. Facing/squash are applied by the scene via node scale.

import SpriteKit

final class AnimatedAvatarNode: SKNode {

    private let avatar: Avatar
    private let provider: SpriteProvider
    private var layers: [(layer: AvatarLayer, node: SKSpriteNode)] = []
    private let displaySize: CGSize

    private var baseState: AnimState = .idle
    private var currentState: AnimState = .idle
    private var frame = 0
    private var frameTimer: CGFloat = 0
    private var oneShotRemaining: CGFloat = 0

    init(avatar: Avatar, provider: SpriteProvider, width: CGFloat, height: CGFloat, isLocal: Bool) {
        self.avatar = avatar
        self.provider = provider
        // Draw slightly larger than the hitbox so the character reads well.
        self.displaySize = CGSize(width: width * 1.5, height: height * 1.5)
        super.init()

        for layer in AvatarLayer.allCases {
            let sprite = SKSpriteNode()
            sprite.size = displaySize
            sprite.zPosition = CGFloat(layer.rawValue)
            if let tint = provider.tint(part: layer, itemId: layer.itemId(in: avatar)) {
                sprite.color = tint
                sprite.colorBlendFactor = 0.82
            }
            addChild(sprite)
            layers.append((layer, sprite))
        }

        if isLocal {
            let outline = SKShapeNode(rectOf: CGSize(width: width + 2, height: height + 2), cornerRadius: 2)
            outline.fillColor = .clear
            outline.strokeColor = .white
            outline.lineWidth = 1
            outline.zPosition = -1
            addChild(outline)
        }

        applyFrame()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func setBaseState(_ state: AnimState) {
        baseState = state
    }

    func playOneShot(_ state: AnimState, duration: CGFloat) {
        currentState = state
        frame = 0
        frameTimer = 0
        oneShotRemaining = duration
        applyFrame()
    }

    func update(_ dt: CGFloat) {
        if oneShotRemaining > 0 {
            oneShotRemaining -= dt
            if oneShotRemaining <= 0 {
                currentState = baseState
                frame = 0
                frameTimer = 0
            }
        } else if currentState != baseState {
            currentState = baseState
            frame = 0
            frameTimer = 0
        }

        let count = provider.frameCount(state: currentState)
        if count > 1 {
            frameTimer += dt
            let secondsPerFrame = 1.0 / max(1, provider.fps(state: currentState))
            while frameTimer >= secondsPerFrame {
                frameTimer -= secondsPerFrame
                if provider.isLooping(state: currentState) {
                    frame = (frame + 1) % count
                } else {
                    frame = min(frame + 1, count - 1)
                }
            }
        }
        applyFrame()
    }

    private func applyFrame() {
        for (layer, sprite) in layers {
            let id = layer.itemId(in: avatar)
            if let texture = provider.texture(part: layer, itemId: id, state: currentState, frame: frame) {
                sprite.texture = texture
                sprite.size = displaySize
                sprite.isHidden = false
            } else {
                sprite.isHidden = true
            }
        }
    }
}
