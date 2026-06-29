// AppModel.swift
// Top-level screen state and the glue from the menu into a local or online
// match. Owns the InputBus and the active GameScene so views stay simple.

import SwiftUI
import ArrowClashSim
import ArrowClashNet

@MainActor
final class AppModel: ObservableObject {
    enum Screen {
        case menu
        case searching
        case playing
    }

    @Published var screen: Screen = .menu
    @Published var statusText: String = ""

    let input = InputBus()
    private(set) var scene: GameScene?

    private var controller: OnlineMatchController?

    func startLocalPractice() {
        let driver = LocalDriver()
        scene = GameScene(input: input, driver: driver)
        screen = .playing
    }

    func findOnlineMatch() {
        statusText = "Connecting..."
        screen = .searching

        let controller = OnlineMatchController()
        self.controller = controller

        controller.onStatus = { [weak self] text in
            Task { @MainActor in self?.statusText = text }
        }
        controller.onError = { [weak self] message in
            Task { @MainActor in
                self?.statusText = "Error: \(message)"
                self?.screen = .menu
            }
        }
        controller.onReady = { [weak self] session in
            Task { @MainActor in
                guard let self = self else { return }
                let driver = OnlineDriver(session: session)
                self.scene = GameScene(input: self.input, driver: driver)
                self.screen = .playing
            }
        }
        controller.start()
    }

    func leave() {
        controller?.leave()
        controller = nil
        scene = nil
        screen = .menu
    }
}
