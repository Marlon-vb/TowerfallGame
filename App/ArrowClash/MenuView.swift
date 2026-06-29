// MenuView.swift
// Start menu: shows level/XP, and routes to online match, local practice,
// loadout, or settings.

import SwiftUI

struct MenuView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var profileService: ProfileService

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.07, blue: 0.10).ignoresSafeArea()
            VStack(spacing: 22) {
                Text("ArrowClash")
                    .font(.system(size: 44, weight: .heavy))
                    .foregroundColor(.white)

                if let profile = profileService.profile {
                    Text("Level \(profile.level)   -   \(profile.xp) XP")
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
                    Button("Loadout") { model.openLoadout() }
                        .buttonStyle(MenuButtonStyle(prominent: false))
                    Button("Settings") { model.openSettings() }
                        .buttonStyle(MenuButtonStyle(prominent: false))
                    if !model.statusText.isEmpty {
                        Text(model.statusText).font(.footnote).foregroundColor(.orange)
                    }
                }
            }
            .padding(40)
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
