// ProfileService.swift
// Reads and updates the player's progression through server RPCs. The client
// never writes progression storage directly; all changes go through the
// authenticated RPCs (get_profile, match_end, set_loadout), which compute and
// persist values server-side.
//
// Written against nakama-swift v1.2.0. Untested in this environment; SDK API
// specifics are confined to this file.

import Foundation
import Nakama

@MainActor
final class ProfileService: ObservableObject {
    @Published var profile: PlayerProfile?
    @Published var statusText: String = ""

    var serverHost: String = "127.0.0.1"
    var serverPort: Int = 7349
    var serverKey: String = "defaultkey"
    var useSSL: Bool = false

    private let auth: AuthProvider
    private var client: GrpcClient?
    private var session: Session?

    init(auth: AuthProvider = DeviceAuthProvider()) {
        self.auth = auth
    }

    private func ensureSession() async throws -> (GrpcClient, Session) {
        if let client = client, let session = session {
            return (client, session)
        }
        let client = GrpcClient(serverKey: serverKey, host: serverHost, port: serverPort, ssl: useSSL)
        let session = try await client.authenticateDevice(id: auth.identifier(), create: true, username: nil, vars: nil, retryConfig: nil)
        self.client = client
        self.session = session
        return (client, session)
    }

    private func call(_ id: String, payload: String?) async throws -> PlayerProfile? {
        let (client, session) = try await ensureSession()
        let response = try await client.rpc(session: session, id: id, payload: payload, retryConfig: nil)
        guard let body = response?.payload, let data = body.data(using: .utf8) else { return nil }
        return try JSONDecoder().decode(PlayerProfile.self, from: data)
    }

    func refresh() async {
        do {
            if let p = try await call("get_profile", payload: nil) {
                profile = p
            }
        } catch {
            statusText = "\(error)"
        }
    }

    private struct MatchEndRequest: Encodable { let won: Bool; let kills: Int; let rounds: Int }

    func submitMatchEnd(won: Bool, kills: Int, rounds: Int) async {
        do {
            let data = try JSONEncoder().encode(MatchEndRequest(won: won, kills: kills, rounds: rounds))
            if let p = try await call("match_end", payload: String(data: data, encoding: .utf8)) {
                profile = p
            }
        } catch {
            statusText = "\(error)"
        }
    }

    @discardableResult
    func setLoadout(skin: String, trail: String) async -> Bool {
        do {
            let data = try JSONEncoder().encode(CosmeticLoadout(skin: skin, trail: trail))
            if let p = try await call("set_loadout", payload: String(data: data, encoding: .utf8)) {
                profile = p
                return true
            }
            return false
        } catch {
            statusText = "\(error)"
            return false
        }
    }
}
