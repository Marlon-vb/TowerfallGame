// Cosmetics.swift
// Client mirror of the server cosmetic catalog and XP curve, plus the colors
// used to render each cosmetic. The server is authoritative for ownership and
// XP; this is for display and to render loadouts in-match.

import UIKit

struct CosmeticLoadout: Codable, Equatable {
    var skin: String
    var trail: String
    static let `default` = CosmeticLoadout(skin: "skin_blue", trail: "trail_white")
}

struct PlayerProfile: Codable, Equatable {
    var xp: Int
    var level: Int
    var loadout: CosmeticLoadout
    static let placeholder = PlayerProfile(xp: 0, level: 1, loadout: .default)
}

struct CosmeticItem: Identifiable {
    let id: String
    let kind: String   // "skin" or "trail"
    let requiredLevel: Int
    let color: UIColor
}

enum Cosmetics {
    static let items: [CosmeticItem] = [
        CosmeticItem(id: "skin_blue", kind: "skin", requiredLevel: 1, color: UIColor(red: 0.30, green: 0.75, blue: 1.00, alpha: 1)),
        CosmeticItem(id: "skin_red", kind: "skin", requiredLevel: 1, color: UIColor(red: 1.00, green: 0.45, blue: 0.40, alpha: 1)),
        CosmeticItem(id: "skin_green", kind: "skin", requiredLevel: 2, color: UIColor(red: 0.40, green: 0.85, blue: 0.45, alpha: 1)),
        CosmeticItem(id: "skin_gold", kind: "skin", requiredLevel: 5, color: UIColor(red: 1.00, green: 0.84, blue: 0.20, alpha: 1)),
        CosmeticItem(id: "trail_white", kind: "trail", requiredLevel: 1, color: .white),
        CosmeticItem(id: "trail_fire", kind: "trail", requiredLevel: 3, color: UIColor(red: 1.00, green: 0.50, blue: 0.15, alpha: 1)),
        CosmeticItem(id: "trail_ice", kind: "trail", requiredLevel: 4, color: UIColor(red: 0.50, green: 0.85, blue: 1.00, alpha: 1)),
    ]

    static var skins: [CosmeticItem] { items.filter { $0.kind == "skin" } }
    static var trails: [CosmeticItem] { items.filter { $0.kind == "trail" } }

    static func item(_ id: String) -> CosmeticItem? { items.first { $0.id == id } }

    static func skinColor(_ id: String) -> UIColor {
        item(id)?.color ?? UIColor(red: 0.30, green: 0.75, blue: 1.00, alpha: 1)
    }
    static func trailColor(_ id: String) -> UIColor {
        item(id)?.color ?? .white
    }
    static func isOwned(_ id: String, level: Int) -> Bool {
        guard let it = item(id) else { return false }
        return level >= it.requiredLevel
    }

    // Display-only mirror of the server curve (server stays authoritative).
    static func xpToReach(level: Int) -> Int {
        level <= 1 ? 0 : 50 * (level - 1) * level
    }
}
