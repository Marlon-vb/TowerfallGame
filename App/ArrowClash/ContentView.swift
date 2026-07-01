// ContentView.swift
// Routes between the menu and an active match based on AppModel state.

import SwiftUI

struct ContentView: View {
    @StateObject private var model = AppModel()

    var body: some View {
        switch model.screen {
        case .menu, .searching:
            MenuView(model: model, profileService: model.profileService)
        case .customize:
            CustomizeView(profileService: model.profileService,
                          onClose: { model.backToMenu() },
                          onStore: { model.openStore() })
        case .store:
            StoreView(profileService: model.profileService, onClose: { model.openCustomize() })
        case .settings:
            SettingsView(onClose: { model.closeSettings() })
        case .leaderboard:
            LeaderboardView(profileService: model.profileService, onClose: { model.backToMenu() })
        case .playing:
            if let scene = model.scene {
                GameView(scene: scene, model: model)
            } else {
                MenuView(model: model, profileService: model.profileService)
            }
        }
    }
}
