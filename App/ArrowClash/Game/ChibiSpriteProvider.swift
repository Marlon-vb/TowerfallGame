// ChibiSpriteProvider.swift
// Loads the generated chibi layer sprites (tools/generate_pixel_art.py) from
// Sprites/chibi/<layer>/<state>/east_<i>.png. Layers are grayscale and tinted
// at runtime by the equipped item's catalog color, so one sheet per part covers
// every color variant. Outlines/eyes are near-black in the source art and stay
// dark through the multiplicative tint.
//
// This is the default in-match look (tiny big-head chibi, bold outline - see
// docs/ART_DIRECTION.md). FileSpriteProvider (the hand-generated single-layer
// base) remains available as an alternative provider.

import SpriteKit
import UIKit

final class ChibiSpriteProvider: SpriteProvider {

    static let shared = ChibiSpriteProvider()

    let nativeFrameSize = CGSize(width: 24, height: 24)

    private struct Anim {
        let folder: String
        let count: Int
        let fps: CGFloat
        let loop: Bool
    }

    private let anims: [AnimState: Anim] = [
        .idle:  Anim(folder: "idle",  count: 2, fps: 3,  loop: true),
        .run:   Anim(folder: "run",   count: 4, fps: 10, loop: true),
        .jump:  Anim(folder: "jump",  count: 1, fps: 1,  loop: false),
        .fall:  Anim(folder: "fall",  count: 1, fps: 1,  loop: false),
        .dash:  Anim(folder: "dash",  count: 1, fps: 1,  loop: false),
        .shoot: Anim(folder: "shoot", count: 2, fps: 12, loop: false),
        .die:   Anim(folder: "die",   count: 1, fps: 1,  loop: false),
    ]

    private var cache: [String: SKTexture] = [:]

    func frameCount(state: AnimState) -> Int { anims[state]?.count ?? 1 }
    func fps(state: AnimState) -> CGFloat { anims[state]?.fps ?? 1 }
    func isLooping(state: AnimState) -> Bool { anims[state]?.loop ?? false }

    func tint(part: AvatarLayer, itemId: String) -> SKColor? {
        return Catalog.color(itemId)
    }

    // Maps a layer + equipped item to its sprite folder. Head accessories and
    // bows have one folder per style (ids match folder names); "head_none"
    // hides the layer. Bow folders only contain shoot frames, so the layer is
    // hidden in every other state automatically.
    private func layerFolder(part: AvatarLayer, itemId: String) -> String? {
        switch part {
        case .skin: return "skin"
        case .hair: return "hair"
        case .shirt: return "shirt"
        case .pants: return "pants"
        case .head: return itemId == "head_none" ? nil : itemId
        case .bow: return itemId.isEmpty ? "bow_wood" : itemId
        }
    }

    func texture(part: AvatarLayer, itemId: String, state: AnimState, frame: Int) -> SKTexture? {
        guard let anim = anims[state], let folder = layerFolder(part: part, itemId: itemId) else { return nil }
        let index = min(frame, anim.count - 1)
        let key = "\(folder)-\(anim.folder)-\(index)"
        if let tex = cache[key] { return tex }

        let subdir = "Sprites/chibi/\(folder)/\(anim.folder)"
        guard let url = Bundle.main.url(forResource: "east_\(index)", withExtension: "png", subdirectory: subdir),
              let image = UIImage(contentsOfFile: url.path) else {
            return nil
        }
        let tex = SKTexture(image: image)
        tex.filteringMode = .nearest
        cache[key] = tex
        return tex
    }
}
