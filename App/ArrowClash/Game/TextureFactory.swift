// TextureFactory.swift
// Generates simple textures at runtime (no asset files): soft radial glow,
// vertical gradients, and a vignette. Used for lighting, atmosphere, and
// particle effects. All original/procedural.

import UIKit
import SpriteKit

enum TextureFactory {

    private static func render(_ size: CGSize, _ draw: (CGContext) -> Void) -> SKTexture {
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            draw(ctx.cgContext)
        }
        return SKTexture(image: image)
    }

    // Soft white radial dot, transparent at the edge. Tint it via node.color +
    // colorBlendFactor and blendMode .add for glow.
    static func radialGlow(diameter: CGFloat = 64) -> SKTexture {
        return render(CGSize(width: diameter, height: diameter)) { c in
            let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            guard let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) else { return }
            let center = CGPoint(x: diameter / 2, y: diameter / 2)
            c.drawRadialGradient(grad, startCenter: center, startRadius: 0, endCenter: center, endRadius: diameter / 2, options: [])
        }
    }

    static func verticalGradient(top: UIColor, bottom: UIColor, size: CGSize) -> SKTexture {
        return render(size) { c in
            let colors = [top.cgColor, bottom.cgColor] as CFArray
            guard let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) else { return }
            c.drawLinearGradient(grad, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: size.height), options: [])
        }
    }

    static func vignette(size: CGSize, strength: CGFloat = 0.55) -> SKTexture {
        return render(size) { c in
            let colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(strength).cgColor] as CFArray
            guard let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.5, 1]) else { return }
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = max(size.width, size.height) * 0.72
            c.drawRadialGradient(grad, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
        }
    }
}

extension UIColor {
    func adjustBrightness(_ factor: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if getHue(&h, saturation: &s, brightness: &b, alpha: &a) {
            return UIColor(hue: h, saturation: s, brightness: max(0, min(1, b * factor)), alpha: a)
        }
        var r: CGFloat = 0, g: CGFloat = 0, bb: CGFloat = 0, aa: CGFloat = 0
        getRed(&r, green: &g, blue: &bb, alpha: &aa)
        return UIColor(red: max(0, min(1, r * factor)), green: max(0, min(1, g * factor)), blue: max(0, min(1, bb * factor)), alpha: aa)
    }
}
