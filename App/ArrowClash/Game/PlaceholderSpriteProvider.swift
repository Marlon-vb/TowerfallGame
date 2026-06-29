// PlaceholderSpriteProvider.swift
// Procedurally generates simple ANIMATED part frames (grayscale, bordered) so
// the layered sprite pipeline runs and characters animate before real art is
// sourced. Frames are drawn at a fixed canvas; the node tints each layer by the
// equipped item's color. Textures are cached after first use.
//
// Real art replaces this with an atlas-backed provider; nothing else changes.

import SpriteKit

final class PlaceholderSpriteProvider: SpriteProvider {

    static let shared = PlaceholderSpriteProvider()

    private let canvas = CGSize(width: 24, height: 34)
    private var cache: [String: SKTexture] = [:]

    var nativeFrameSize: CGSize { canvas }

    // MARK: SpriteProvider

    func frameCount(state: AnimState) -> Int {
        switch state {
        case .idle: return 2
        case .run: return 4
        case .shoot: return 2
        case .jump, .fall, .dash, .die: return 1
        }
    }

    func fps(state: AnimState) -> CGFloat {
        switch state {
        case .idle: return 3
        case .run: return 12
        case .shoot: return 16
        default: return 1
        }
    }

    func isLooping(state: AnimState) -> Bool {
        state == .idle || state == .run
    }

    func tint(part: AvatarLayer, itemId: String) -> SKColor? {
        return Catalog.color(itemId)
    }

    func texture(part: AvatarLayer, itemId: String, state: AnimState, frame: Int) -> SKTexture? {
        if part == .head {
            let style = Catalog.accessory(itemId)
            if style == .none { return nil }
            return cached("head-\(styleKey(style))-\(stateKey(state))-\(frame)") { ctx in
                self.drawAccessory(ctx, style: style, pose: self.pose(state, frame))
            }
        }
        return cached("\(part.rawValue)-\(stateKey(state))-\(frame)") { ctx in
            self.drawBody(ctx, part: part, pose: self.pose(state, frame))
        }
    }

    // MARK: Pose

    private struct Pose {
        var bobY: CGFloat = 0   // + moves down
        var legL: CGFloat = 0
        var legR: CGFloat = 0
        var legLen: CGFloat = 12
        var lean: CGFloat = 0
    }

    private func pose(_ state: AnimState, _ frame: Int) -> Pose {
        var p = Pose()
        switch state {
        case .idle:
            p.bobY = frame == 1 ? -1 : 0
        case .run:
            switch frame {
            case 0: p.legL = 3; p.legR = -3; p.bobY = -1
            case 2: p.legL = -3; p.legR = 3; p.bobY = -1
            default: p.legL = 0; p.legR = 0
            }
        case .jump:
            p.legL = -1; p.legR = 1; p.legLen = 9; p.bobY = -1
        case .fall:
            p.legL = -3; p.legR = 3; p.legLen = 13
        case .dash:
            p.lean = 3
        case .shoot:
            p.lean = frame == 1 ? -1.5 : 0
        case .die:
            p.bobY = 6
        }
        return p
    }

    // MARK: Drawing

    private func drawBody(_ ctx: CGContext, part: AvatarLayer, pose: Pose) {
        let cx: CGFloat = 12
        switch part {
        case .pants:
            let topY = canvas.height - pose.legLen
            box(ctx, CGRect(x: cx - 5 + pose.legL + pose.lean, y: topY, width: 4, height: pose.legLen))
            box(ctx, CGRect(x: cx + 1 + pose.legR + pose.lean, y: topY, width: 4, height: pose.legLen))
        case .shirt:
            box(ctx, CGRect(x: cx - 6 + pose.lean, y: 13 + pose.bobY, width: 12, height: 10))
        case .skin:
            box(ctx, CGRect(x: cx - 4 + pose.lean, y: 5 + pose.bobY, width: 8, height: 9))
        case .hair:
            box(ctx, CGRect(x: cx - 5 + pose.lean, y: 2 + pose.bobY, width: 10, height: 5))
        case .head:
            break
        }
    }

    private func drawAccessory(_ ctx: CGContext, style: AccessoryStyle, pose: Pose) {
        let cx: CGFloat = 12
        let topY: CGFloat = pose.bobY
        let lean = pose.lean
        switch style {
        case .none:
            break
        case .cap:
            box(ctx, CGRect(x: cx - 5 + lean, y: 1 + topY, width: 10, height: 4))
            box(ctx, CGRect(x: cx - 7 + lean, y: 4 + topY, width: 14, height: 2))
        case .helmet:
            box(ctx, CGRect(x: cx - 6 + lean, y: 0 + topY, width: 12, height: 8))
        case .horns:
            box(ctx, CGRect(x: cx - 7 + lean, y: 0 + topY, width: 2, height: 6))
            box(ctx, CGRect(x: cx + 5 + lean, y: 0 + topY, width: 2, height: 6))
        case .halo:
            ring(ctx, center: CGPoint(x: cx + lean, y: 1 + topY), radius: 5)
        case .crown:
            box(ctx, CGRect(x: cx - 5 + lean, y: 3 + topY, width: 10, height: 3))
            for dx in [CGFloat(-5), 0, 5] {
                box(ctx, CGRect(x: cx + dx - 1 + lean, y: 0 + topY, width: 2, height: 4))
            }
        }
    }

    // White box with a darker 1px border, so tinting (blend < 1) keeps an edge.
    private func box(_ ctx: CGContext, _ rect: CGRect) {
        ctx.setFillColor(UIColor(white: 0.22, alpha: 1).cgColor)
        ctx.fill(rect)
        let inner = rect.insetBy(dx: 1, dy: 1)
        if inner.width > 0 && inner.height > 0 {
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.fill(inner)
        }
    }

    private func ring(_ ctx: CGContext, center: CGPoint, radius: CGFloat) {
        ctx.setStrokeColor(UIColor.white.cgColor)
        ctx.setLineWidth(1.5)
        ctx.strokeEllipse(in: CGRect(x: center.x - radius, y: center.y, width: radius * 2, height: radius * 1.4))
    }

    // MARK: Cache

    private func cached(_ key: String, _ draw: @escaping (CGContext) -> Void) -> SKTexture {
        if let tex = cache[key] { return tex }
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = 2
        let image = UIGraphicsImageRenderer(size: canvas, format: format).image { rc in
            draw(rc.cgContext)
        }
        let tex = SKTexture(image: image)
        tex.filteringMode = .nearest
        cache[key] = tex
        return tex
    }

    private func stateKey(_ s: AnimState) -> String {
        switch s {
        case .idle: return "idle"
        case .run: return "run"
        case .jump: return "jump"
        case .fall: return "fall"
        case .dash: return "dash"
        case .shoot: return "shoot"
        case .die: return "die"
        }
    }

    private func styleKey(_ s: AccessoryStyle) -> String {
        switch s {
        case .none: return "none"
        case .cap: return "cap"
        case .helmet: return "helmet"
        case .horns: return "horns"
        case .halo: return "halo"
        case .crown: return "crown"
        }
    }
}
