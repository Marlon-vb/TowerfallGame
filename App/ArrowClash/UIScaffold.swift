// UIScaffold.swift
// Reusable screen container: centers content when it fits the (landscape) screen
// and scrolls when it doesn't, respects safe areas, and caps content width so
// layouts read well on every iPhone size.

import SwiftUI

struct ScreenScaffold<Content: View>: View {
    var maxContentWidth: CGFloat = 460
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    content()
                        .frame(maxWidth: maxContentWidth)
                        .frame(maxWidth: .infinity) // center the capped content
                        .padding(.horizontal, 24)
                        .padding(.vertical, 18)
                    Spacer(minLength: 0)
                }
                .frame(minHeight: geo.size.height)
            }
        }
    }
}
