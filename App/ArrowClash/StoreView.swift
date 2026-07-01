// StoreView.swift
// Buy store items (cost > 0) with coins earned by playing. Purchases are
// validated and applied server-side via ProfileService; equip them in Customize.

import SwiftUI

struct StoreView: View {
    @ObservedObject var profileService: ProfileService
    var onClose: () -> Void

    private var profile: PlayerProfile { profileService.profile ?? .placeholder }
    private var storeItems: [StoreItem] { Catalog.items.filter { $0.cost > 0 } }

    private let columns = [GridItem(.adaptive(minimum: 90), spacing: 12)]

    var body: some View {
        ZStack {
            PixelBackground(name: "menu", scrim: 0.6)
            ScreenScaffold(maxContentWidth: 560) {
              VStack(spacing: 12) {
                HStack {
                    Text("Store").font(.system(size: 26, weight: .heavy)).foregroundColor(.white)
                    Spacer()
                    Text("\(profile.coins) coins").font(.subheadline).foregroundColor(.yellow)
                }

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(storeItems) { item in
                        cell(item)
                    }
                }

                if !profileService.statusText.isEmpty {
                    Text(profileService.statusText).font(.caption2).foregroundColor(.orange).lineLimit(1)
                }

                Button("Back") { onClose() }
                    .buttonStyle(SmallButtonStyle(prominent: false))
                    .padding(.top, 6)
              }
            }
        }
        .task { await profileService.refresh() }
    }

    private func cell(_ item: StoreItem) -> some View {
        let owned = Catalog.isOwned(item.id, profile: profile)
        let affordable = profile.coins >= item.cost
        return VStack(spacing: 6) {
            Circle().fill(Color(uiColor: item.color)).frame(width: 40, height: 40)
            Text(CosmeticNaming.name(item.id)).font(.system(size: 11, weight: .semibold)).foregroundColor(.white)
            if owned {
                Text("Owned").font(.system(size: 10)).foregroundColor(.green)
            } else {
                Button {
                    Task { await profileService.purchase(item.id) }
                } label: {
                    Text("\(item.cost)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(affordable ? .black : .white.opacity(0.5))
                        .frame(width: 60, height: 26)
                        .background(RoundedRectangle(cornerRadius: 6).fill(affordable ? Color.yellow : Color.white.opacity(0.12)))
                }
                .disabled(!affordable)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
    }
}
