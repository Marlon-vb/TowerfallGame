// ContentView.swift
// Routes between the menu and an active match based on AppModel state.

import SwiftUI

struct ContentView: View {
    @StateObject private var model = AppModel()

    var body: some View {
        switch model.screen {
        case .menu, .searching:
            MenuView(model: model)
        case .playing:
            if let scene = model.scene {
                GameView(scene: scene, input: model.input, onLeave: { model.leave() })
            } else {
                MenuView(model: model)
            }
        }
    }
}
