// AvatarRenderer.swift
// Builds a layered blocky avatar (legs/torso/head/hair + head accessory) as an
// SKNode sized to the player AABB. Original geometric art; colors come from the
// avatar's equipped items. Children are positioned relative to the node center
// (y-up, matching the scene). The scene positions the whole node each frame.

import SpriteKit

enum AvatarRenderer {

    static func build(avatar: Avatar, width: CGFloat, height: CGFloat, isLocal: Bool) -> SKNode {
        let container = SKNode()

        let skin = Catalog.color(avatar.skin)
        let hair = Catalog.color(avatar.hair)
        let shirt = Catalog.color(avatar.shirt)
        let pants = Catalog.color(avatar.pants)

        let halfH = height / 2

        // Proportions as fractions of height, from the bottom up.
        // legs 0.30, torso 0.34, head 0.28, hair sits on top of the head.
        let legsH = height * 0.30
        let torsoH = height * 0.34
        let headH = height * 0.28

        let legsCY = -halfH + legsH / 2
        let torsoCY = -halfH + legsH + torsoH / 2
        let headCY = -halfH + legsH + torsoH + headH / 2

        container.addChild(rect(width: width * 0.8, height: legsH, color: pants, cy: legsCY))
        container.addChild(rect(width: width * 0.92, height: torsoH, color: shirt, cy: torsoCY))
        container.addChild(rect(width: width * 0.74, height: headH, color: skin, cy: headCY))
        // Hair: a cap across the top third of the head.
        let hairH = headH * 0.45
        let hairCY = headCY + headH / 2 - hairH / 2
        container.addChild(rect(width: width * 0.78, height: hairH, color: hair, cy: hairCY))

        if let accessory = accessoryNode(Catalog.accessory(avatar.head),
                                         color: Catalog.color(avatar.head),
                                         width: width, height: height, headCY: headCY, headH: headH) {
            container.addChild(accessory)
        }

        if isLocal {
            let outline = SKShapeNode(rectOf: CGSize(width: width + 2, height: height + 2), cornerRadius: 2)
            outline.fillColor = .clear
            outline.strokeColor = .white
            outline.lineWidth = 1
            outline.zPosition = -1
            container.addChild(outline)
        }

        return container
    }

    private static func rect(width: CGFloat, height: CGFloat, color: SKColor, cy: CGFloat) -> SKShapeNode {
        let node = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 1)
        node.fillColor = color
        node.strokeColor = .clear
        node.position = CGPoint(x: 0, y: cy)
        return node
    }

    private static func accessoryNode(_ style: AccessoryStyle, color: SKColor, width: CGFloat, height: CGFloat, headCY: CGFloat, headH: CGFloat) -> SKNode? {
        let topY = headCY + headH / 2
        switch style {
        case .none:
            return nil
        case .cap:
            let group = SKNode()
            group.addChild(rect(width: width * 0.82, height: headH * 0.4, color: color, cy: topY))
            let brim = rect(width: width * 1.0, height: 1.5, color: color, cy: topY - headH * 0.2)
            group.addChild(brim)
            return group
        case .helmet:
            return rect(width: width * 0.9, height: headH * 0.8, color: color, cy: headCY + headH * 0.1)
        case .horns:
            let group = SKNode()
            let left = rect(width: 2, height: headH * 0.5, color: color, cy: topY + headH * 0.2)
            left.position = CGPoint(x: -width * 0.3, y: topY + headH * 0.2)
            let right = rect(width: 2, height: headH * 0.5, color: color, cy: topY + headH * 0.2)
            right.position = CGPoint(x: width * 0.3, y: topY + headH * 0.2)
            group.addChild(left); group.addChild(right)
            return group
        case .halo:
            let ring = SKShapeNode(circleOfRadius: width * 0.35)
            ring.fillColor = .clear
            ring.strokeColor = color
            ring.lineWidth = 1.5
            ring.position = CGPoint(x: 0, y: topY + headH * 0.45)
            return ring
        case .crown:
            let group = SKNode()
            group.addChild(rect(width: width * 0.7, height: headH * 0.25, color: color, cy: topY + 1))
            for dx in [-0.25, 0.0, 0.25] {
                let spike = rect(width: 1.5, height: headH * 0.3, color: color, cy: topY + headH * 0.25)
                spike.position = CGPoint(x: width * CGFloat(dx), y: topY + headH * 0.25)
                group.addChild(spike)
            }
            return group
        }
    }
}
