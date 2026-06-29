// SpriteProvider.swift
// Model + protocol for the layered sprite pipeline. A character is composited
// from one layer per body part, all sharing the same animation timeline. The
// provider supplies textures + tints; swap PlaceholderSpriteProvider for an
// atlas-backed one when real art arrives, with no other changes.
//
// Render-only: animation state is chosen from the synced sim state, so both
// clients look consistent without affecting the simulation.

import SpriteKit

enum AnimState: Equatable {
    case idle, run, jump, fall, dash, shoot, die
}

// Layers in back-to-front draw order. Each maps to an avatar slot.
enum AvatarLayer: Int, CaseIterable {
    case pants, shirt, skin, hair, head

    var slot: String {
        switch self {
        case .pants: return "pants"
        case .shirt: return "shirt"
        case .skin: return "skin"
        case .hair: return "hair"
        case .head: return "head"
        }
    }

    func itemId(in avatar: Avatar) -> String {
        switch self {
        case .pants: return avatar.pants
        case .shirt: return avatar.shirt
        case .skin: return avatar.skin
        case .hair: return avatar.hair
        case .head: return avatar.head
        }
    }
}

protocol SpriteProvider {
    func frameCount(state: AnimState) -> Int
    func fps(state: AnimState) -> CGFloat
    func isLooping(state: AnimState) -> Bool
    // Returns the texture for a part at a given state/frame, or nil if the part
    // should be hidden (e.g. head accessory "none").
    func texture(part: AvatarLayer, itemId: String, state: AnimState, frame: Int) -> SKTexture?
    // Tint color for a part (nil = use texture as-is).
    func tint(part: AvatarLayer, itemId: String) -> SKColor?
}
