// LoadoutView.swift
// Shows the player's level/XP and the cosmetic catalog. Unlocked cosmetics
// (level >= required) can be equipped; the equip call is validated and persisted
// server-side via ProfileService.

import SwiftUI

struct LoadoutView: View {
    @ObservedObject var profileService: ProfileService
    var onClose: () -> Void

    private var profile: PlayerProfile { profileService.profile ?? .placeholder }

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.07, blue: 0.10).ignoresSafeArea()
            VStack(spacing: 18) {
                header
                section(title: "Skin", items: Cosmetics.skins, current: profile.loadout.skin) { id in
                    Task { await profileService.setLoadout(skin: id, trail: profile.loadout.trail) }
                }
                section(title: "Arrow Trail", items: Cosmetics.trails, current: profile.loadout.trail) { id in
                    Task { await profileService.setLoadout(skin: profile.loadout.skin, trail: id) }
                }
                if !profileService.statusText.isEmpty {
                    Text(profileService.statusText).font(.caption).foregroundColor(.orange)
                }
                Spacer()
                Button("Back") { onClose() }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 200, height: 46)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.15)))
            }
            .padding(28)
        }
        .task { await profileService.refresh() }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("Loadout").font(.system(size: 30, weight: .heavy)).foregroundColor(.white)
            Text("Level \(profile.level)   -   \(profile.xp) XP")
                .font(.subheadline).foregroundColor(.white.opacity(0.8))
            Text("Next level at \(Cosmetics.xpToReach(level: profile.level + 1)) XP")
                .font(.caption2).foregroundColor(.white.opacity(0.5))
        }
    }

    private func section(title: String, items: [CosmeticItem], current: String, onPick: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).foregroundColor(.white)
            HStack(spacing: 12) {
                ForEach(items) { item in
                    let owned = profile.level >= item.requiredLevel
                    let selected = item.id == current
                    Button { if owned { onPick(item.id) } } label: {
                        VStack(spacing: 4) {
                            Circle()
                                .fill(Color(uiColor: item.color))
                                .frame(width: 40, height: 40)
                                .overlay(Circle().stroke(selected ? Color.white : Color.clear, lineWidth: 3))
                                .opacity(owned ? 1.0 : 0.3)
                            Text(owned ? (selected ? "Equipped" : "Equip") : "Lvl \(item.requiredLevel)")
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(owned ? 0.9 : 0.5))
                        }
                    }
                    .disabled(!owned)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
