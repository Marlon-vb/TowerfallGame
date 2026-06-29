// AppModel.swift
// Top-level screen state and the glue from the menu into a local or online
// match, plus progression. Owns the InputBus, the active GameScene, and the
// ProfileService.

import SwiftUI
import ArrowClashSim
import ArrowClashNet

@MainActor
final class AppModel: ObservableObject {
    enum Screen {
        case menu
        case loadout
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
    let profileService = ProfileService()
    private(set) var scene: GameScene?

    private var controller: OnlineMatchController?
    private var mode: Mode = .local

    func startLocalPractice() {
        mode = .local
        matchResult = nil
        let own = profileService.profile?.loadout ?? .default
        scene = makeScene(driver: LocalDriver(), loadouts: [own, .default])
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
        controller.onReady = { [weak self] session, loadouts in
            Task { @MainActor in
                guard let self = self else { return }
                let driver = OnlineDriver(session: session)
                self.scene = self.makeScene(driver: driver, loadouts: loadouts)
                self.screen = .playing
            }
        }
        controller.start()
    }

    func openLoadout() {
        screen = .loadout
        Task { await profileService.refresh() }
    }

    func closeLoadout() {
        screen = .menu
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

    private func makeScene(driver: SceneDriver, loadouts: [CosmeticLoadout]) -> GameScene {
        var ld = loadouts
        while ld.count < 2 { ld.append(.default) }
        let skins = ld.map { Cosmetics.skinColor($0.skin) }
        let trails = ld.map { Cosmetics.trailColor($0.trail) }

        let scene = GameScene(input: input, driver: driver, skinColors: skins, trailColors: trails)
        scene.onMatchEnd = { [weak self] won, kills, rounds in
            Task { @MainActor in
                self?.matchResult = won
                await self?.profileService.submitMatchEnd(won: won, kills: kills, rounds: rounds)
            }
        }
        return scene
    }
}
