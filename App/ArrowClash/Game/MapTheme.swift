// MapTheme.swift
// Render-only color themes per map id, so the 10 arenas look distinct. Not part
// of the sim (purely visual), but identical on both clients because it is keyed
// by the shared map id.

import UIKit

struct MapTheme {
    let tile: UIColor
    let background: UIColor
}

enum MapThemes {
    // Indexed by map id; falls back to the first if out of range.
    static let all: [MapTheme] = [
        MapTheme(tile: UIColor(red: 0.22, green: 0.24, blue: 0.30, alpha: 1), background: UIColor(red: 0.08, green: 0.09, blue: 0.12, alpha: 1)), // Arena
        MapTheme(tile: UIColor(red: 0.32, green: 0.22, blue: 0.30, alpha: 1), background: UIColor(red: 0.12, green: 0.07, blue: 0.12, alpha: 1)), // Pillars
        MapTheme(tile: UIColor(red: 0.20, green: 0.30, blue: 0.26, alpha: 1), background: UIColor(red: 0.06, green: 0.12, blue: 0.10, alpha: 1)), // Stairs
        MapTheme(tile: UIColor(red: 0.30, green: 0.28, blue: 0.20, alpha: 1), background: UIColor(red: 0.12, green: 0.10, blue: 0.06, alpha: 1)), // Towers
        MapTheme(tile: UIColor(red: 0.24, green: 0.26, blue: 0.34, alpha: 1), background: UIColor(red: 0.07, green: 0.08, blue: 0.14, alpha: 1)), // Cross
        MapTheme(tile: UIColor(red: 0.30, green: 0.24, blue: 0.22, alpha: 1), background: UIColor(red: 0.12, green: 0.08, blue: 0.07, alpha: 1)), // Ledges
        MapTheme(tile: UIColor(red: 0.22, green: 0.30, blue: 0.32, alpha: 1), background: UIColor(red: 0.06, green: 0.11, blue: 0.12, alpha: 1)), // Bridges
        MapTheme(tile: UIColor(red: 0.28, green: 0.22, blue: 0.34, alpha: 1), background: UIColor(red: 0.10, green: 0.07, blue: 0.14, alpha: 1)), // Diamond
        MapTheme(tile: UIColor(red: 0.26, green: 0.28, blue: 0.22, alpha: 1), background: UIColor(red: 0.09, green: 0.10, blue: 0.07, alpha: 1)), // Layers
        MapTheme(tile: UIColor(red: 0.30, green: 0.26, blue: 0.30, alpha: 1), background: UIColor(red: 0.11, green: 0.09, blue: 0.11, alpha: 1)), // Scatter
    ]

    static func theme(for id: Int) -> MapTheme {
        (id >= 0 && id < all.count) ? all[id] : all[0]
    }
}
