// LeaderboardView.swift
// Global XP leaderboard, read from the server's authoritative arrowclash_xp
// leaderboard (only the server runtime writes records to it).

import SwiftUI

struct LeaderboardView: View {
    @ObservedObject var profileService: ProfileService
    var onClose: () -> Void

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.07, blue: 0.10).ignoresSafeArea()
            ScreenScaffold {
              VStack(spacing: 12) {
                Text("Leaderboard")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundColor(.white)

                if profileService.leaderboard.isEmpty {
                    Text("No matches played yet - be the first!")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.vertical, 24)
                } else {
                    VStack(spacing: 6) {
                        ForEach(profileService.leaderboard) { entry in
                            HStack(spacing: 12) {
                                Text("#\(entry.rank)")
                                    .font(.system(size: 15, weight: .heavy, design: .monospaced))
                                    .foregroundColor(rankColor(entry.rank))
                                    .frame(width: 44, alignment: .leading)
                                Text(entry.username)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(entry.xp) XP")
                                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.75))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
                        }
                    }
                }

                if !profileService.statusText.isEmpty {
                    Text(profileService.statusText).font(.footnote).foregroundColor(.orange)
                }

                Button("Back") { onClose() }
                    .buttonStyle(SmallButtonStyle(prominent: false))
                    .padding(.top, 6)
              }
            }
        }
        .task { await profileService.refreshLeaderboard() }
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return Color(red: 1.0, green: 0.84, blue: 0.25)
        case 2: return Color(red: 0.80, green: 0.82, blue: 0.88)
        case 3: return Color(red: 0.80, green: 0.55, blue: 0.30)
        default: return .white.opacity(0.55)
        }
    }
}
