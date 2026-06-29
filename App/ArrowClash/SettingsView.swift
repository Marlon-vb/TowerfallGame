// SettingsView.swift
// Basic settings: sound toggle and the server host (so a physical device can
// point at the Mac's LAN IP without editing code).

import SwiftUI

struct SettingsView: View {
    var onClose: () -> Void

    @State private var soundEnabled = Settings.soundEnabled
    @State private var serverHost = Settings.serverHost

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.07, blue: 0.10).ignoresSafeArea()
            VStack(spacing: 22) {
                Text("Settings")
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundColor(.white)

                Toggle("Sound", isOn: $soundEnabled)
                    .onChange(of: soundEnabled) { newValue in Settings.soundEnabled = newValue }
                    .foregroundColor(.white)
                    .frame(width: 280)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Server host").font(.caption).foregroundColor(.white.opacity(0.7))
                    TextField("127.0.0.1", text: $serverHost)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                        .onChange(of: serverHost) { newValue in Settings.serverHost = newValue }
                    Text("Simulator: 127.0.0.1. Physical device: your Mac's LAN IP.")
                        .font(.caption2).foregroundColor(.white.opacity(0.5))
                }
                .frame(width: 280)

                Spacer()
                Button("Back") { onClose() }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 200, height: 46)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.15)))
            }
            .padding(28)
        }
    }
}
