// MenuView.swift
// One-page 16-bit start menu over the generated pixel backdrop: rank badge,
// two primary actions, and a compact secondary row. No scrolling.

import SwiftUI

// Full-bleed pixel background image from Sprites/backgrounds, with a dark
// scrim so UI text stays readable.
struct PixelBackground: View {
    let name: String
    var scrim: Double = 0.25

    private static var cache: [String: UIImage] = [:]

    private var image: UIImage? {
        if let cached = Self.cache[name] { return cached }
        guard let url = Bundle.main.url(forResource: name, withExtension: "png",
                                        subdirectory: "Sprites/backgrounds"),
              let img = UIImage(contentsOfFile: url.path) else { return nil }
        Self.cache[name] = img
        return img
    }

    var body: some View {
        ZStack {
            if let img = image {
                Image(uiImage: img)
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
            } else {
                Color(red: 0.10, green: 0.08, blue: 0.18).ignoresSafeArea()
            }
            Color.black.opacity(scrim).ignoresSafeArea()
        }
    }
}

struct MenuView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var profileService: ProfileService

    private var profile: PlayerProfile { profileService.profile ?? .placeholder }
    private var tier: RankTier { RankTier.tier(for: profile.rating) }

    // The generated pixel logotype (Sprites/ui/title.png).
    private static let titleImage: UIImage? = {
        guard let url = Bundle.main.url(forResource: "title", withExtension: "png",
                                        subdirectory: "Sprites/ui") else { return nil }
        return UIImage(contentsOfFile: url.path)
    }()

    var body: some View {
        ZStack {
            PixelBackground(name: "menu")

            // Your own character hangs out on the battlement (bottom-left).
            VStack {
                Spacer()
                HStack {
                    AvatarPreview(avatar: profile.avatar)
                        .frame(width: 84, height: 84)
                        .padding(.leading, 34)
                        .padding(.bottom, 6)
                    Spacer()
                }
            }

            VStack(spacing: 14) {
                Spacer(minLength: 4)

                if let title = Self.titleImage {
                    Image(uiImage: title)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 52)
                } else {
                    Text("ARROWCLASH")
                        .font(.system(size: 40, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)
                        .shadow(color: Color(red: 0.16, green: 0.12, blue: 0.30), radius: 0, x: 3, y: 3)
                }

                // Rank badge + progression line.
                HStack(spacing: 10) {
                    Text(tier.name.uppercased())
                        .font(.system(size: 12, weight: .heavy, design: .monospaced))
                        .foregroundColor(.black.opacity(0.8))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(uiColor: tier.color))
                        .cornerRadius(4)
                    Text("\(profile.rating)")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    Text("Lv \(profile.level)  •  \(profile.coins) coins")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.85))
                }

                if model.screen == .searching {
                    VStack(spacing: 12) {
                        ProgressView().progressViewStyle(.circular).tint(.white)
                        Text(model.statusText)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.white.opacity(0.85))
                        Button("Cancel") { model.leave() }
                            .buttonStyle(PixelButtonStyle(prominent: false))
                    }
                    .padding(.top, 8)
                } else {
                    VStack(spacing: 10) {
                        Button("RANKED MATCH") { model.findOnlineMatch() }
                            .buttonStyle(PixelButtonStyle(prominent: true))
                        Button("PRACTICE") { model.startLocalPractice() }
                            .buttonStyle(PixelButtonStyle(prominent: false))
                    }

                    HStack(spacing: 8) {
                        Button("Customize") { model.openCustomize() }
                            .buttonStyle(PixelButtonStyle(prominent: false, compact: true))
                        Button("Store") { model.openStore() }
                            .buttonStyle(PixelButtonStyle(prominent: false, compact: true))
                        Button("Ranks") { model.openLeaderboard() }
                            .buttonStyle(PixelButtonStyle(prominent: false, compact: true))
                        Button("Settings") { model.openSettings() }
                            .buttonStyle(PixelButtonStyle(prominent: false, compact: true))
                    }

                    if !model.statusText.isEmpty {
                        Text(model.statusText)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.orange)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 4)
            }
            .padding(.horizontal, 20)
        }
        .onAppear { model.refreshProfile() }
    }
}

// Chunky pixel-style button: hard shadow, no blur, monospaced label.
struct PixelButtonStyle: ButtonStyle {
    let prominent: Bool
    var compact: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 13 : 17, weight: .heavy, design: .monospaced))
            .foregroundColor(prominent ? .black : .white)
            .frame(width: compact ? 92 : 250, height: compact ? 36 : 48)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black.opacity(0.55))
                        .offset(x: 2, y: 3)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(prominent
                              ? Color(red: 0.98, green: 0.82, blue: 0.25)
                              : Color(red: 0.25, green: 0.22, blue: 0.40))
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.black.opacity(0.8), lineWidth: 2)
                }
            )
            .offset(y: configuration.isPressed ? 2 : 0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
    }
}

// Kept for compatibility with older screens that still use it.
struct MenuButtonStyle: ButtonStyle {
    let prominent: Bool
    func makeBody(configuration: Configuration) -> some View {
        PixelButtonStyle(prominent: prominent).makeBody(configuration: configuration)
    }
}
