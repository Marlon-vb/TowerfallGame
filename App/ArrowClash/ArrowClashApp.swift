// ArrowClashApp.swift
// App entry point. Phase 0 has no gameplay rendering yet; this shell exists so
// the iOS target compiles and links the deterministic sim package. SpriteKit
// rendering and touch input arrive in Phase 1.

import SwiftUI

@main
struct ArrowClashApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
