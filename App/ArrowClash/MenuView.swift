// MenuView.swift
// Minimal start menu: local practice or find an online 1v1. Polished menus,
// loadout and post-match screens come in later phases.

import SwiftUI

struct MenuView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.07, blue: 0.10).ignoresSafeArea()
            VStack(spacing: 24) {
                Text("ArrowClash")
                    .font(.system(size: 44, weight: .heavy))
                    .foregroundColor(.white)

                if model.screen == .searching {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                    Text(model.statusText)
                        .foregroundColor(.white.opacity(0.8))
                    Button("Cancel") { model.leave() }
                        .buttonStyle(MenuButtonStyle(prominent: false))
                } else {
                    Button("Find Online Match") { model.findOnlineMatch() }
                        .buttonStyle(MenuButtonStyle(prominent: true))
                    Button("Local Practice") { model.startLocalPractice() }
                        .buttonStyle(MenuButtonStyle(prominent: false))
                    Button("Loadout") { model.openLoadout() }
                        .buttonStyle(MenuButtonStyle(prominent: false))
                    if !model.statusText.isEmpty {
                        Text(model.statusText)
                            .font(.footnote)
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding(40)
        }
    }
}

private struct MenuButtonStyle: ButtonStyle {
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
