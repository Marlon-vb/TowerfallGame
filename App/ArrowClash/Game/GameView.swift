// GameView.swift
// Hosts the SpriteKit scene and the touch controls in one SwiftUI view. The
// scene and the controls share a single InputBus.

import SwiftUI
import SpriteKit

struct GameView: View {
    @StateObject private var holder = SceneHolder()

    var body: some View {
        ZStack {
            SpriteView(scene: holder.scene)
                .ignoresSafeArea()
            ControlsOverlay(input: holder.input)
        }
        .statusBarHidden(true)
    }
}

final class SceneHolder: ObservableObject {
    let input: InputBus
    let scene: GameScene

    init() {
        let bus = InputBus()
        self.input = bus
        self.scene = GameScene(input: bus)
    }
}
