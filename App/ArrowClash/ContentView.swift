// ContentView.swift
// Routes between the menu and an active match based on AppModel state.

import SwiftUI

struct ContentView: View {
    @StateObject private var model = AppModel()

    var body: some View {
        switch model.screen {
        case .menu, .searching:
            MenuView(model: model, profileService: model.profileService)
        case .loadout:
            LoadoutView(profileService: model.profileService, onClose: { model.closeLoadout() })
        case .settings:
            SettingsView(onClose: { model.closeSettings() })
        case .playing:
            if let scene = model.scene {
                GameView(scene: scene, model: model)
            } else {
                MenuView(model: model)
            }
        }
    }
}
