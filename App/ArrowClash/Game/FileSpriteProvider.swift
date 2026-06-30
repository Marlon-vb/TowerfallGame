// FileSpriteProvider.swift
// Loads real per-frame PNGs from the app bundle (Sprites/skin/<state>/east_<i>.png).
// These are the hand-generated chibi poses normalized by tools/normalize_sprites.py
// into uniform 64x64 transparent frames, east-only (the scene mirrors for left),
// full color (no tint). See App/ArrowClash/Sprites/skin/NOTES.md.
//
// Only the base body ("skin") has art today; other layers return nil (hidden)
// until their sheets exist. Swap-in point for the layered pipeline.

import SpriteKit
import UIKit

final class FileSpriteProvider: SpriteProvider {

    static let shared = FileSpriteProvider()

    let nativeFrameSize = CGSize(width: 64, height: 64)

    // start = first file index to use (kept for forward-compat; all 0 now).
    private struct Anim {
        let folder: String
        let start: Int
        let count: Int
        let fps: CGFloat
        let loop: Bool
    }

    // One key pose per state today (run/shoot have two). Single-frame states
    // hold their pose; add frames by dropping more PNGs and bumping count.
    private let anims: [AnimState: Anim] = [
        .idle:  Anim(folder: "idle",  start: 0, count: 1, fps: 2,  loop: true),
        .run:   Anim(folder: "run",   start: 0, count: 2, fps: 10, loop: true),
        .jump:  Anim(folder: "jump",  start: 0, count: 1, fps: 1,  loop: false),
        .fall:  Anim(folder: "fall",  start: 0, count: 1, fps: 1,  loop: false),
        .dash:  Anim(folder: "dash",  start: 0, count: 1, fps: 1,  loop: false),
        .shoot: Anim(folder: "shoot", start: 0, count: 2, fps: 14, loop: false),
        .die:   Anim(folder: "die",   start: 0, count: 1, fps: 1,  loop: false),
    ]

    private var cache: [String: SKTexture] = [:]

    func frameCount(state: AnimState) -> Int { anims[state]?.count ?? 1 }
    func fps(state: AnimState) -> CGFloat { anims[state]?.fps ?? 1 }
    func isLooping(state: AnimState) -> Bool { anims[state]?.loop ?? false }

    // Base art is full color; no engine tint.
    func tint(part: AvatarLayer, itemId: String) -> SKColor? { nil }

    func texture(part: AvatarLayer, itemId: String, state: AnimState, frame: Int) -> SKTexture? {
        // Only the base body has art right now.
        guard part == .skin, let anim = anims[state] else { return nil }
        let fileIndex = anim.start + frame
        let key = "\(anim.folder)-\(fileIndex)"
        if let tex = cache[key] { return tex }

        let subdir = "Sprites/skin/\(anim.folder)"
        guard let url = Bundle.main.url(forResource: "east_\(fileIndex)", withExtension: "png", subdirectory: subdir),
              let image = UIImage(contentsOfFile: url.path) else {
            return nil
        }
        let tex = SKTexture(image: image)
        tex.filteringMode = .nearest
        cache[key] = tex
        return tex
    }
}
