// Settings.swift
// Simple persisted settings backed by UserDefaults.

import Foundation

enum Settings {
    private static let soundKey = "arrowclash.soundEnabled"
    private static let hostKey = "arrowclash.serverHost"

    static var soundEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: soundKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: soundKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: soundKey) }
    }

    static var serverHost: String {
        get { UserDefaults.standard.string(forKey: hostKey) ?? "127.0.0.1" }
        set { UserDefaults.standard.set(newValue, forKey: hostKey) }
    }
}
