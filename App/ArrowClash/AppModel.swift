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

    enum Mode {
        case local
        case online
    }

    @Published var screen: Screen = .menu
    @Published var statusText: String = ""
    // nil while a match is in progress; set to win/lose when the match ends.
    @Published var matchResult: Bool?

    let input = InputBus()
    private(set) var scene: GameScene?

    private var controller: OnlineMatchController?
    private var mode: Mode = .local

    func startLocalPractice() {
        mode = .local
        matchResult = nil
        let driver = LocalDriver()
        scene = makeScene(driver: driver)
        screen = .playing
    }

    func findOnlineMatch() {
        mode = .online
        matchResult = nil
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
                self.scene = self.makeScene(driver: driver)
                self.screen = .playing
            }
        }
        controller.start()
    }

    func rematch() {
        matchResult = nil
        switch mode {
        case .online:
            controller?.leave()
            controller = nil
            findOnlineMatch()
        case .local:
            startLocalPractice()
        }
    }

    func leave() {
        controller?.leave()
        controller = nil
        scene = nil
        matchResult = nil
        screen = .menu
    }

    private func makeScene(driver: SceneDriver) -> GameScene {
        let scene = GameScene(input: input, driver: driver)
        scene.onMatchEnd = { [weak self] localWon in
            Task { @MainActor in self?.matchResult = localWon }
        }
        return scene
    }
}
