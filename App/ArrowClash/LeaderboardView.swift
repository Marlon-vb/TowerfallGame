// LeaderboardView.swift
// Global XP leaderboard, read from the server's authoritative arrowclash_xp
// leaderboard (only the server runtime writes records to it).

import SwiftUI

struct LeaderboardView: View {
    @ObservedObject var profileService: ProfileService
    var onClose: () -> Void

    var body: some View {
        ZStack {
            PixelBackground(name: "menu", scrim: 0.6)
            ScreenScaffold {
              VStack(spacing: 12) {
                Text("RANKED LADDER")
                    .font(.system(size: 22, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)

                if profileService.leaderboard.isEmpty {
                    Text("No ranked matches yet - be the first!")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.vertical, 24)
                } else {
                    VStack(spacing: 6) {
                        ForEach(profileService.leaderboard) { entry in
                            let tier = RankTier.tier(for: entry.score)
                            HStack(spacing: 10) {
                                Text("#\(entry.rank)")
                                    .font(.system(size: 14, weight: .heavy, design: .monospaced))
                                    .foregroundColor(rankColor(entry.rank))
                                    .frame(width: 40, alignment: .leading)
                                Text(tier.name.uppercased())
                                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                    .foregroundColor(.black.opacity(0.8))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color(uiColor: tier.color))
                                    .cornerRadius(3)
                                Text(entry.username)
                                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(entry.score)")
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.85))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.35)))
                        }
                    }
                }

                if !profileService.statusText.isEmpty {
                    Text(profileService.statusText).font(.footnote).foregroundColor(.orange)
                }

                Button("Back") { onClose() }
                    .buttonStyle(PixelButtonStyle(prominent: false, compact: true))
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
