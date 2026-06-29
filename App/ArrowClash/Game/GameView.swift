// GameView.swift
// Hosts a prebuilt GameScene plus the touch controls, a Leave button, and the
// post-match overlay.

import SwiftUI
import SpriteKit

struct GameView: View {
    let scene: GameScene
    @ObservedObject var model: AppModel

    var body: some View {
        ZStack {
            SpriteView(scene: scene)
                .ignoresSafeArea()
            ControlsOverlay(input: model.input)
            VStack {
                HStack {
                    Button("Leave") { model.leave() }
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

            if let won = model.matchResult {
                PostMatchOverlay(didWin: won,
                                 onRematch: { model.rematch() },
                                 onMenu: { model.leave() })
            }
        }
        .statusBarHidden(true)
    }
}

private struct PostMatchOverlay: View {
    let didWin: Bool
    var onRematch: () -> Void
    var onMenu: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 22) {
                Text(didWin ? "Victory" : "Defeat")
                    .font(.system(size: 40, weight: .heavy))
                    .foregroundColor(didWin ? .green : .red)
                HStack(spacing: 16) {
                    Button("Rematch", action: onRematch)
                        .buttonStyle(OverlayButtonStyle(prominent: true))
                    Button("Menu", action: onMenu)
                        .buttonStyle(OverlayButtonStyle(prominent: false))
                }
            }
        }
    }
}

private struct OverlayButtonStyle: ButtonStyle {
    let prominent: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: 150, height: 48)
            .background(RoundedRectangle(cornerRadius: 10)
                .fill(prominent ? Color.blue.opacity(0.85) : Color.white.opacity(0.15)))
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}
