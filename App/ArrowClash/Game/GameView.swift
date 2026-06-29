// GameView.swift
// Hosts a prebuilt GameScene plus the touch controls and a Leave button.

import SwiftUI
import SpriteKit

struct GameView: View {
    let scene: GameScene
    let input: InputBus
    var onLeave: () -> Void

    var body: some View {
        ZStack {
            SpriteView(scene: scene)
                .ignoresSafeArea()
            ControlsOverlay(input: input)
            VStack {
                HStack {
                    Button("Leave") { onLeave() }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.black.opacity(0.4)))
                    Spacer()
                }
                Spacer()
            }
            .padding(16)
        }
        .statusBarHidden(true)
    }
}
