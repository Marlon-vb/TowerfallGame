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
    var bow: String

    static let `default` = Avatar(skin: "skin_2", hair: "hair_brown", shirt: "shirt_gray",
                                  pants: "pants_navy", head: "head_none", trail: "trail_white",
                                  bow: "bow_wood")

    init(skin: String, hair: String, shirt: String, pants: String,
         head: String, trail: String, bow: String) {
        self.skin = skin
        self.hair = hair
        self.shirt = shirt
        self.pants = pants
        self.head = head
        self.trail = trail
        self.bow = bow
    }

    // Backward-compatible decoding: profiles stored before the bow slot
    // existed decode with the default bow.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        skin = try c.decode(String.self, forKey: .skin)
        hair = try c.decode(String.self, forKey: .hair)
        shirt = try c.decode(String.self, forKey: .shirt)
        pants = try c.decode(String.self, forKey: .pants)
        head = try c.decode(String.self, forKey: .head)
        trail = try c.decode(String.self, forKey: .trail)
        bow = try c.decodeIfPresent(String.self, forKey: .bow) ?? "bow_wood"
    }
}

struct PlayerProfile: Codable, Equatable {
    var xp: Int
    var level: Int
    var coins: Int
    var owned: [String]
    var avatar: Avatar
    var rating: Int
    static let placeholder = PlayerProfile(xp: 0, level: 1, coins: 0, owned: [], avatar: .default, rating: 1000)

    init(xp: Int, level: Int, coins: Int, owned: [String], avatar: Avatar, rating: Int) {
        self.xp = xp
        self.level = level
        self.coins = coins
        self.owned = owned
        self.avatar = avatar
        self.rating = rating
    }

    // Profiles from servers predating ranked decode with the base rating.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        xp = try c.decodeIfPresent(Int.self, forKey: .xp) ?? 0
        level = try c.decodeIfPresent(Int.self, forKey: .level) ?? 1
        coins = try c.decodeIfPresent(Int.self, forKey: .coins) ?? 0
        owned = try c.decodeIfPresent([String].self, forKey: .owned) ?? []
        avatar = try c.decodeIfPresent(Avatar.self, forKey: .avatar) ?? .default
        rating = try c.decodeIfPresent(Int.self, forKey: .rating) ?? 1000
    }
}

// Ranked tiers derived from the ELO rating.
enum RankTier: CaseIterable {
    case bronze, silver, gold, diamond, champion

    static func tier(for rating: Int) -> RankTier {
        switch rating {
        case ..<1100: return .bronze
        case ..<1300: return .silver
        case ..<1500: return .gold
        case ..<1800: return .diamond
        default: return .champion
        }
    }

    var name: String {
        switch self {
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold: return "Gold"
        case .diamond: return "Diamond"
        case .champion: return "Champion"
        }
    }

    var color: UIColor {
        switch self {
        case .bronze: return UIColor(red: 0.75, green: 0.52, blue: 0.30, alpha: 1)
        case .silver: return UIColor(red: 0.78, green: 0.80, blue: 0.86, alpha: 1)
        case .gold: return UIColor(red: 0.98, green: 0.82, blue: 0.25, alpha: 1)
        case .diamond: return UIColor(red: 0.55, green: 0.85, blue: 0.98, alpha: 1)
        case .champion: return UIColor(red: 0.90, green: 0.45, blue: 0.90, alpha: 1)
        }
    }
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
        // Head accessories. Tintable ones carry a color; the fun full-color
        // ones are white (a white multiply tint leaves the art unchanged).
        item("head_none", "head", 0, .clear, .none),
        item("head_cap", "head", 100, rgb(0.80, 0.20, 0.20), .cap),
        item("head_helmet", "head", 200, rgb(0.70, 0.70, 0.75), .helmet),
        item("head_horns", "head", 250, rgb(0.95, 0.95, 0.90), .horns),
        item("head_halo", "head", 350, rgb(1.00, 0.95, 0.40), .halo),
        item("head_crown", "head", 500, rgb(1.00, 0.84, 0.20), .crown),
        // Limited fun heads (full-color art).
        item("head_fish", "head", 600, .white),
        item("head_crow", "head", 550, .white),
        item("head_tv", "head", 500, .white),
        item("head_frog", "head", 450, .white),
        item("head_cat", "head", 350, .white),
        item("head_wizard", "head", 400, .white),
        item("head_pirate", "head", 400, .white),
        item("head_viking", "head", 400, .white),
        item("head_ninja", "head", 300, .white),
        // Bows (full-color art; visible while shooting).
        item("bow_wood", "bow", 0, .white),
        item("bow_silver", "bow", 300, .white),
        item("bow_gold", "bow", 500, .white),
        item("bow_crystal", "bow", 800, .white),
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
        case "bow": return avatar.bow
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
        case "bow": a.bow = id
        default: break
        }
        return a
    }

    // Display order of slots for the customize screen.
    static let customizeSlots = ["skin", "hair", "shirt", "pants", "head", "bow", "trail"]

    private static func item(_ id: String, _ slot: String, _ cost: Int, _ color: UIColor, _ accessory: AccessoryStyle = .none) -> StoreItem {
        StoreItem(id: id, slot: slot, cost: cost, color: color, accessory: accessory)
    }
    private static func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> UIColor {
        UIColor(red: r, green: g, blue: b, alpha: 1)
    }
}
