// LoadoutView.swift
// Character customizer: equip owned items per slot (skin/hair/shirt/pants/head/
// trail). Owned = free base items plus anything purchased. Locked items show
// their cost and route to the Store. Equip changes are validated/persisted
// server-side via ProfileService.

import SwiftUI

struct CustomizeView: View {
    @ObservedObject var profileService: ProfileService
    var onClose: () -> Void
    var onStore: () -> Void

    private var profile: PlayerProfile { profileService.profile ?? .placeholder }

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.07, blue: 0.10).ignoresSafeArea()
            ScreenScaffold {
              VStack(spacing: 12) {
                HStack {
                    Text("Customize").font(.system(size: 26, weight: .heavy)).foregroundColor(.white)
                    Spacer()
                    Text("\(profile.coins) coins").font(.subheadline).foregroundColor(.yellow)
                }

                AvatarPreview(avatar: profile.avatar)
                    .frame(width: 70, height: 100)

                ForEach(Catalog.customizeSlots, id: \.self) { slot in
                    slotSection(slot)
                }

                HStack(spacing: 14) {
                    Button("Store") { onStore() }
                        .buttonStyle(SmallButtonStyle(prominent: true))
                    Button("Back") { onClose() }
                        .buttonStyle(SmallButtonStyle(prominent: false))
                }
                .padding(.top, 6)
              }
            }
        }
        .task { await profileService.refresh() }
    }

    private func slotSection(_ slot: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(CosmeticNaming.slotTitle(slot)).font(.headline).foregroundColor(.white)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Catalog.items(slot: slot)) { item in
                        swatch(item, slot: slot)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func swatch(_ item: StoreItem, slot: String) -> some View {
        let owned = Catalog.isOwned(item.id, profile: profile)
        let selected = Catalog.equipped(profile.avatar, slot: slot) == item.id
        return Button {
            if owned {
                Task { await profileService.setAvatar(Catalog.equipping(profile.avatar, slot: slot, id: item.id)) }
            }
        } label: {
            VStack(spacing: 3) {
                Circle()
                    .fill(item.id == "head_none" ? Color.white.opacity(0.12) : Color(uiColor: item.color))
                    .frame(width: 38, height: 38)
                    .overlay(Circle().stroke(selected ? Color.white : Color.clear, lineWidth: 3))
                    .opacity(owned ? 1 : 0.3)
                Text(owned ? CosmeticNaming.name(item.id) : "\(item.cost)")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(owned ? 0.9 : 0.5))
            }
        }
        .disabled(!owned)
    }
}

// A simple SwiftUI preview of the layered avatar (mirrors AvatarRenderer order).
struct AvatarPreview: View {
    let avatar: Avatar
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            VStack(spacing: 0) {
                Rectangle().fill(Color(uiColor: Catalog.color(avatar.hair)))
                    .frame(width: w * 0.78, height: h * 0.13)
                Rectangle().fill(Color(uiColor: Catalog.color(avatar.skin)))
                    .frame(width: w * 0.74, height: h * 0.17)
                Rectangle().fill(Color(uiColor: Catalog.color(avatar.shirt)))
                    .frame(width: w * 0.92, height: h * 0.34)
                Rectangle().fill(Color(uiColor: Catalog.color(avatar.pants)))
                    .frame(width: w * 0.80, height: h * 0.30)
            }
            .frame(width: w, height: h, alignment: .bottom)
        }
    }
}

struct SmallButtonStyle: ButtonStyle {
    let prominent: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: 130, height: 44)
            .background(RoundedRectangle(cornerRadius: 10)
                .fill(prominent ? Color.blue.opacity(0.85) : Color.white.opacity(0.15)))
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

enum CosmeticNaming {
    static func name(_ id: String) -> String {
        let parts = id.split(separator: "_")
        if id.hasPrefix("skin_"), let n = parts.last { return "Tone \(n)" }
        return parts.dropFirst().joined(separator: " ").capitalized
    }
    static func slotTitle(_ slot: String) -> String {
        switch slot {
        case "skin": return "Skin"
        case "hair": return "Hair"
        case "shirt": return "Shirt"
        case "pants": return "Pants"
        case "head": return "Head"
        case "trail": return "Arrow Trail"
        default: return slot.capitalized
        }
    }
}
