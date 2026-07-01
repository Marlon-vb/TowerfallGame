// LoadoutView.swift
// Character customizer: a large live preview next to one row per slot with
// left/right arrows that cycle through the OWNED items for that slot (locked
// items are skipped; the Store sells them). Equip changes are validated and
// persisted server-side via ProfileService. One page, no scrolling.

import SwiftUI

struct CustomizeView: View {
    @ObservedObject var profileService: ProfileService
    var onClose: () -> Void
    var onStore: () -> Void

    private var profile: PlayerProfile { profileService.profile ?? .placeholder }

    var body: some View {
        ZStack {
            PixelBackground(name: "menu", scrim: 0.55)
            VStack(spacing: 10) {
                HStack {
                    Text("CUSTOMIZE")
                        .font(.system(size: 22, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(profile.coins) coins")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.yellow)
                }

                HStack(alignment: .center, spacing: 18) {
                    // Live composited preview.
                    AvatarPreview(avatar: profile.avatar)
                        .frame(width: 110, height: 110)
                        .background(
                            RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.35))
                        )

                    // One arrow-row per slot.
                    VStack(spacing: 5) {
                        ForEach(Catalog.customizeSlots, id: \.self) { slot in
                            slotRow(slot)
                        }
                    }
                }

                if !profileService.statusText.isEmpty {
                    Text(profileService.statusText)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.orange)
                        .lineLimit(1)
                }

                HStack(spacing: 12) {
                    Button("Store") { onStore() }
                        .buttonStyle(PixelButtonStyle(prominent: true, compact: true))
                    Button("Back") { onClose() }
                        .buttonStyle(PixelButtonStyle(prominent: false, compact: true))
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
        }
        .task { await profileService.refresh() }
    }

    // "Hair   <  Blue  >" - arrows cycle through owned items for the slot.
    private func slotRow(_ slot: String) -> some View {
        let current = Catalog.equipped(profile.avatar, slot: slot)
        let item = Catalog.item(current)
        return HStack(spacing: 8) {
            Text(CosmeticNaming.slotTitle(slot))
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.75))
                .frame(width: 82, alignment: .leading)

            Button { cycle(slot, direction: -1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(.white)
                    .frame(width: 30, height: 26)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.14)))
            }

            HStack(spacing: 6) {
                if let item = item, item.color != .clear {
                    Circle()
                        .fill(Color(uiColor: item.color))
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.black.opacity(0.5), lineWidth: 1))
                }
                Text(CosmeticNaming.name(current))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: 118)

            Button { cycle(slot, direction: 1) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(.white)
                    .frame(width: 30, height: 26)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.14)))
            }
        }
    }

    // Steps to the next/previous OWNED item in the slot (wraps around).
    private func cycle(_ slot: String, direction: Int) {
        let owned = Catalog.items(slot: slot).filter { Catalog.isOwned($0.id, profile: profile) }
        guard owned.count > 1 else { return }
        let current = Catalog.equipped(profile.avatar, slot: slot)
        let index = owned.firstIndex { $0.id == current } ?? 0
        let next = owned[(index + direction + owned.count) % owned.count]
        Task { await profileService.setAvatar(Catalog.equipping(profile.avatar, slot: slot, id: next.id)) }
    }
}

// A simple SwiftUI preview of the layered avatar (mirrors AvatarRenderer order).
// Composites the real chibi layer sprites (idle frame 0), each multiplied by
// its equipped item color - the same recipe the in-match renderer uses.
struct AvatarPreview: View {
    let avatar: Avatar

    private static var imageCache: [String: UIImage] = [:]

    private func layerImage(_ folder: String) -> UIImage? {
        if let cached = Self.imageCache[folder] { return cached }
        guard let url = Bundle.main.url(forResource: "east_0", withExtension: "png",
                                        subdirectory: "Sprites/chibi/\(folder)/idle"),
              let img = UIImage(contentsOfFile: url.path) else { return nil }
        Self.imageCache[folder] = img
        return img
    }

    private var layers: [(folder: String, itemId: String)] {
        var result: [(String, String)] = [
            ("pants", avatar.pants),
            ("shirt", avatar.shirt),
            ("skin", avatar.skin),
            ("hair", avatar.hair),
        ]
        if avatar.head != "head_none" {
            result.append((avatar.head, avatar.head))
        }
        return result
    }

    var body: some View {
        ZStack {
            ForEach(layers, id: \.folder) { layer in
                if let img = layerImage(layer.folder) {
                    Image(uiImage: img)
                        .interpolation(.none)
                        .resizable()
                        .colorMultiply(Color(uiColor: Catalog.color(layer.itemId)))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
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
    private static let overrides: [String: String] = [
        "head_none": "None", "head_fish": "Fish Head", "head_crow": "Pet Crow",
        "head_tv": "TV Head", "head_frog": "Frog Hood", "head_cat": "Cat Ears",
        "head_wizard": "Wizard Hat", "head_pirate": "Pirate Hat",
        "head_viking": "Viking Helm", "head_ninja": "Ninja Band",
    ]

    static func name(_ id: String) -> String {
        if let n = overrides[id] { return n }
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
        case "bow": return "Bow"
        case "trail": return "Arrow Trail"
        default: return slot.capitalized
        }
    }
}
