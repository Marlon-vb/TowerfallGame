// Cosmetics.swift
// Avatar model + item catalog (client mirror of the server). An avatar is a set
// of equipped item ids, one per slot. Items with cost 0 are free base options;
// cost > 0 are store items bought with coins. The server is authoritative for
// ownership/coins; this provides ids, costs (display), colors, and accessory
// shapes for rendering and the store/customize UI.

import UIKit

struct Avatar: Codable, Equatable {
    var skin: String
    var hair: String
    var shirt: String
    var pants: String
    var head: String
    var trail: String

    static let `default` = Avatar(skin: "skin_2", hair: "hair_brown", shirt: "shirt_gray",
                                  pants: "pants_navy", head: "head_none", trail: "trail_white")
}

struct PlayerProfile: Codable, Equatable {
    var xp: Int
    var level: Int
    var coins: Int
    var owned: [String]
    var avatar: Avatar
    static let placeholder = PlayerProfile(xp: 0, level: 1, coins: 0, owned: [], avatar: .default)
}

enum AccessoryStyle {
    case none, cap, helmet, horns, halo, crown
}

struct StoreItem: Identifiable {
    let id: String
    let slot: String          // "skin","hair","shirt","pants","head","trail"
    let cost: Int             // 0 == free base
    let color: UIColor        // primary color (also accessory color)
    let accessory: AccessoryStyle
}

enum Catalog {
    // Ids/costs/slots MUST match nakama/catalog.go.
    static let items: [StoreItem] = [
        // Skin tones (free).
        item("skin_1", "skin", 0, rgb(1.00, 0.87, 0.75)),
        item("skin_2", "skin", 0, rgb(0.95, 0.78, 0.62)),
        item("skin_3", "skin", 0, rgb(0.80, 0.60, 0.45)),
        item("skin_4", "skin", 0, rgb(0.60, 0.42, 0.30)),
        item("skin_5", "skin", 0, rgb(0.40, 0.27, 0.20)),
        // Hair (free base + premium).
        item("hair_black", "hair", 0, rgb(0.10, 0.10, 0.10)),
        item("hair_brown", "hair", 0, rgb(0.35, 0.22, 0.12)),
        item("hair_blonde", "hair", 0, rgb(0.90, 0.80, 0.40)),
        item("hair_red", "hair", 0, rgb(0.70, 0.20, 0.12)),
        item("hair_gray", "hair", 0, rgb(0.60, 0.60, 0.62)),
        item("hair_white", "hair", 0, rgb(0.95, 0.95, 0.95)),
        item("hair_blue", "hair", 120, rgb(0.30, 0.50, 0.95)),
        item("hair_pink", "hair", 120, rgb(1.00, 0.50, 0.80)),
        // Shirts (free base + premium).
        item("shirt_gray", "shirt", 0, rgb(0.50, 0.50, 0.55)),
        item("shirt_green", "shirt", 0, rgb(0.30, 0.60, 0.35)),
        item("shirt_blue", "shirt", 0, rgb(0.25, 0.45, 0.80)),
        item("shirt_red", "shirt", 0, rgb(0.80, 0.30, 0.30)),
        item("shirt_gold", "shirt", 150, rgb(1.00, 0.84, 0.20)),
        // Pants (free).
        item("pants_navy", "pants", 0, rgb(0.15, 0.20, 0.40)),
        item("pants_brown", "pants", 0, rgb(0.35, 0.25, 0.15)),
        item("pants_black", "pants", 0, rgb(0.12, 0.12, 0.15)),
        item("pants_teal", "pants", 0, rgb(0.15, 0.45, 0.45)),
        // Head accessories.
        item("head_none", "head", 0, .clear, .none),
        item("head_cap", "head", 100, rgb(0.80, 0.20, 0.20), .cap),
        item("head_helmet", "head", 200, rgb(0.70, 0.70, 0.75), .helmet),
        item("head_horns", "head", 250, rgb(0.95, 0.95, 0.90), .horns),
        item("head_halo", "head", 350, rgb(1.00, 0.95, 0.40), .halo),
        item("head_crown", "head", 500, rgb(1.00, 0.84, 0.20), .crown),
        // Trails.
        item("trail_white", "trail", 0, .white),
        item("trail_fire", "trail", 200, rgb(1.00, 0.50, 0.15)),
        item("trail_ice", "trail", 200, rgb(0.50, 0.85, 1.00)),
    ]

    static func items(slot: String) -> [StoreItem] { items.filter { $0.slot == slot } }
    static func item(_ id: String) -> StoreItem? { items.first { $0.id == id } }
    static func color(_ id: String) -> UIColor { item(id)?.color ?? .gray }
    static func accessory(_ id: String) -> AccessoryStyle { item(id)?.accessory ?? .none }

    static func isOwned(_ id: String, profile: PlayerProfile) -> Bool {
        guard let it = item(id) else { return false }
        return it.cost == 0 || profile.owned.contains(id)
    }

    static func equipped(_ avatar: Avatar, slot: String) -> String {
        switch slot {
        case "skin": return avatar.skin
        case "hair": return avatar.hair
        case "shirt": return avatar.shirt
        case "pants": return avatar.pants
        case "head": return avatar.head
        case "trail": return avatar.trail
        default: return ""
        }
    }

    static func equipping(_ avatar: Avatar, slot: String, id: String) -> Avatar {
        var a = avatar
        switch slot {
        case "skin": a.skin = id
        case "hair": a.hair = id
        case "shirt": a.shirt = id
        case "pants": a.pants = id
        case "head": a.head = id
        case "trail": a.trail = id
        default: break
        }
        return a
    }

    // Display order of slots for the customize screen.
    static let customizeSlots = ["skin", "hair", "shirt", "pants", "head", "trail"]

    private static func item(_ id: String, _ slot: String, _ cost: Int, _ color: UIColor, _ accessory: AccessoryStyle = .none) -> StoreItem {
        StoreItem(id: id, slot: slot, cost: cost, color: color, accessory: accessory)
    }
    private static func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> UIColor {
        UIColor(red: r, green: g, blue: b, alpha: 1)
    }
}
