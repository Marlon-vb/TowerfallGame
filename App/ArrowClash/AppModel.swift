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
        case customize
        case store
        case settings
        case leaderboard
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

    init() {
        profileService.serverHost = Settings.serverHost
    }

    func startLocalPractice() {
        mode = .local
        matchResult = nil
        let own = profileService.profile?.avatar ?? .default
        let map = Maps.all.randomElement() ?? Maps.default
        scene = makeScene(driver: LocalDriver(map: map), avatars: [own, .default], map: map)
        screen = .playing
    }

    func findOnlineMatch() {
        mode = .online
        matchResult = nil
        statusText = "Connecting..."
        screen = .searching

        let controller = OnlineMatchController()
        controller.serverHost = Settings.serverHost
        controller.myRating = profileService.profile?.rating ?? 1000
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
        controller.onReady = { [weak self] session, avatars, map in
            Task { @MainActor in
                guard let self = self else { return }
                // The user may have cancelled the search while this was queued;
                // don't drop them into a match they already left.
                guard self.controller === controller, self.screen == .searching else { return }
                let driver = OnlineDriver(session: session)
                self.scene = self.makeScene(driver: driver, avatars: avatars, map: map,
                                            matchId: controller.matchId)
                self.screen = .playing
            }
        }
        controller.start()
    }

    func openCustomize() {
        profileService.serverHost = Settings.serverHost
        screen = .customize
        Task { await profileService.refresh() }
    }

    func openStore() {
        profileService.serverHost = Settings.serverHost
        screen = .store
        Task { await profileService.refresh() }
    }

    func backToMenu() {
        screen = .menu
    }

    func openSettings() {
        screen = .settings
    }

    func openLeaderboard() {
        profileService.serverHost = Settings.serverHost
        screen = .leaderboard
    }

    func closeSettings() {
        // Apply any server-host change to the next connection.
        profileService.serverHost = Settings.serverHost
        profileService.reset()
        screen = .menu
    }

    func refreshProfile() {
        profileService.serverHost = Settings.serverHost
        Task { await profileService.refresh() }
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

    private func makeScene(driver: SceneDriver, avatars: [Avatar], map: MapDefinition,
                           matchId: String? = nil) -> GameScene {
        var av = avatars
        while av.count < 2 { av.append(.default) }
        let theme = MapThemes.theme(for: map.id)

        input.reset() // no held/latched input carries over from a previous match

        let scene = GameScene(input: input, driver: driver, map: map,
                              avatars: av,
                              tileColor: theme.tile, bgColor: theme.background)
        scene.onMatchEnd = { [weak self] won, kills, rounds in
            Task { @MainActor in
                self?.matchResult = won
                // Only real online matches earn rewards; the server verifies the
                // matchId against the relay's match record. Local practice (no
                // matchId) submits nothing.
                if let matchId = matchId {
                    await self?.profileService.submitMatchEnd(matchId: matchId, won: won,
                                                              kills: kills, rounds: rounds)
                }
            }
        }
        return scene
    }
}
