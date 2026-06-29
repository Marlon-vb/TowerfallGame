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
    private var frameIndex = 0
    private var frameTimer: CGFloat = 0
    private var oneShotRemaining: CGFloat = 0

    init(avatar: Avatar, provider: SpriteProvider, width: CGFloat, height: CGFloat, isLocal: Bool) {
        self.avatar = avatar
        self.provider = provider
        // Scale the source frame so the character reads a bit larger than the
        // hitbox, preserving the source aspect ratio.
        let native = provider.nativeFrameSize
        let targetHeight = height * 2.2
        let scale = native.height > 0 ? targetHeight / native.height : 1
        self.displaySize = CGSize(width: native.width * scale, height: native.height * scale)
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

    func playOneShot(_ state: AnimState) {
        currentState = state
        frameIndex = 0
        frameTimer = 0
        let count = CGFloat(provider.frameCount(state: state))
        oneShotRemaining = count / max(1, provider.fps(state: state))
        applyFrame()
    }

    func update(_ dt: CGFloat) {
        if oneShotRemaining > 0 {
            oneShotRemaining -= dt
            if oneShotRemaining <= 0 {
                currentState = baseState
                frameIndex = 0
                frameTimer = 0
            }
        } else if currentState != baseState {
            currentState = baseState
            frameIndex = 0
            frameTimer = 0
        }

        let count = provider.frameCount(state: currentState)
        if count > 1 {
            frameTimer += dt
            let secondsPerFrame = 1.0 / max(1, provider.fps(state: currentState))
            while frameTimer >= secondsPerFrame {
                frameTimer -= secondsPerFrame
                if provider.isLooping(state: currentState) {
                    frameIndex = (frameIndex + 1) % count
                } else {
                    frameIndex = min(frameIndex + 1, count - 1)
                }
            }
        }
        applyFrame()
    }

    private func applyFrame() {
        for (layer, sprite) in layers {
            let id = layer.itemId(in: avatar)
            if let texture = provider.texture(part: layer, itemId: id, state: currentState, frame: frameIndex) {
                sprite.texture = texture
                sprite.size = displaySize
                sprite.isHidden = false
            } else {
                sprite.isHidden = true
            }
        }
    }
}
