// MenuView.swift
// Start menu: shows level/XP, and routes to online match, local practice,
// loadout, or settings.

import SwiftUI

struct MenuView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var profileService: ProfileService

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.10, green: 0.11, blue: 0.18),
                                    Color(red: 0.04, green: 0.04, blue: 0.07)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            ScreenScaffold {
              VStack(spacing: 22) {
                Text("ArrowClash")
                    .font(.system(size: 46, weight: .heavy))
                    .foregroundColor(.white)
                    .shadow(color: Color.cyan.opacity(0.7), radius: 12)
                    .shadow(color: Color.blue.opacity(0.5), radius: 24)

                if let profile = profileService.profile {
                    Text("Level \(profile.level)   -   \(profile.xp) XP   -   \(profile.coins) coins")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }

                if model.screen == .searching {
                    ProgressView().progressViewStyle(.circular).tint(.white)
                    Text(model.statusText).foregroundColor(.white.opacity(0.8))
                    Button("Cancel") { model.leave() }
                        .buttonStyle(MenuButtonStyle(prominent: false))
                } else {
                    Button("Find Online Match") { model.findOnlineMatch() }
                        .buttonStyle(MenuButtonStyle(prominent: true))
                    Button("Local Practice") { model.startLocalPractice() }
                        .buttonStyle(MenuButtonStyle(prominent: false))
                    Button("Customize") { model.openCustomize() }
                        .buttonStyle(MenuButtonStyle(prominent: false))
                    Button("Store") { model.openStore() }
                        .buttonStyle(MenuButtonStyle(prominent: false))
                    Button("Settings") { model.openSettings() }
                        .buttonStyle(MenuButtonStyle(prominent: false))
                    if !model.statusText.isEmpty {
                        Text(model.statusText).font(.footnote).foregroundColor(.orange)
                    }
                }
              }
            }
        }
        .onAppear { model.refreshProfile() }
    }
}

struct MenuButtonStyle: ButtonStyle {
    let prominent: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: 260, height: 52)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(prominent ? Color.blue.opacity(0.85) : Color.white.opacity(0.12))
            )
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}
