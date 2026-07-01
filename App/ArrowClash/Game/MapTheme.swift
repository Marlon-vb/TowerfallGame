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
    // Indexed by map id; falls back to the first if out of range. Pastel
    // palette matching the generated tilesets in tools/generate_pixel_art.py
    // (backgrounds are the THEMES bg values; tiles are the base fill, used only
    // as a fallback when a tileset PNG is missing from the bundle).
    static let all: [MapTheme] = [
        MapTheme(tile: rgb(124, 111, 176), background: rgb(167, 155, 212)), // Arena - lavender
        MapTheme(tile: rgb(168, 114, 144), background: rgb(212, 160, 185)), // Pillars - rose
        MapTheme(tile: rgb(110, 156, 138), background: rgb(155, 196, 180)), // Stairs - sage
        MapTheme(tile: rgb(176, 155, 106), background: rgb(216, 199, 154)), // Towers - sand
        MapTheme(tile: rgb(113, 137, 180), background: rgb(159, 180, 216)), // Cross - periwinkle
        MapTheme(tile: rgb(176, 120, 98),  background: rgb(216, 168, 152)), // Ledges - terracotta
        MapTheme(tile: rgb(106, 152, 166), background: rgb(151, 195, 206)), // Bridges - teal
        MapTheme(tile: rgb(138, 111, 176), background: rgb(182, 155, 212)), // Diamond - violet
        MapTheme(tile: rgb(138, 156, 110), background: rgb(180, 199, 155)), // Layers - moss
        MapTheme(tile: rgb(152, 124, 158), background: rgb(196, 164, 201)), // Scatter - mauve
    ]

    private static func rgb(_ r: Int, _ g: Int, _ b: Int) -> UIColor {
        UIColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
    }

    static func theme(for id: Int) -> MapTheme {
        (id >= 0 && id < all.count) ? all[id] : all[0]
    }
}
