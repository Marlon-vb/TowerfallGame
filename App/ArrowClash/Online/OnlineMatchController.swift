// OnlineMatchController.swift
// Drives the online path: device auth -> connect -> matchmaking -> join match
// -> receive START (slot + shared seed) -> build a RollbackSession fed by a
// NakamaTransport. Auth is behind a tiny seam so Game Center could replace
// device id later.
//
// Written against nakama-swift v1.2.0. connect() is synchronous; matchmaking is
// started from the onConnect callback. All Nakama-SDK usage is confined to this
// file and NakamaTransport.swift.

import Foundation
import ArrowClashSim
import ArrowClashNet
import Nakama

protocol AuthProvider {
    func identifier() -> String
}

// Device-id auth for v1. Swap for a Game Center provider later.
struct DeviceAuthProvider: AuthProvider {
    private let key = "arrowclash.deviceId"
    func identifier() -> String {
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: key)
        return id
    }
}

final class OnlineMatchController {

    // Change to your Mac's LAN IP when testing on a physical device; the
    // simulator can use 127.0.0.1 to reach Nakama running on the same Mac.
    var serverHost: String = "127.0.0.1"
    var serverPort: Int = 7349
    var serverKey: String = "defaultkey"
    var useSSL: Bool = false

    var onStatus: ((String) -> Void)?
    var onReady: ((RollbackSession, [CosmeticLoadout]) -> Void)?
    var onError: ((String) -> Void)?

    private let auth: AuthProvider
    private var client: GrpcClient?
    private var socket: SocketProtocol?
    private var nakamaSession: Session?
    private var transport: NakamaTransport?
    private var matchId: String?
    private var didStart = false

    init(auth: AuthProvider = DeviceAuthProvider()) {
        self.auth = auth
    }

    func start() {
        Task { await connectAndQueue() }
    }

    private func connectAndQueue() async {
        do {
            onStatus?("Connecting...")
            let client = GrpcClient(serverKey: serverKey, host: serverHost, port: serverPort, ssl: useSSL)
            self.client = client

            let session = try await client.authenticateDevice(id: auth.identifier(), create: true, username: nil, vars: nil, retryConfig: nil)
            self.nakamaSession = session

            // SocketProtocol is not class-constrained, so a mutable binding is
            // required to set its callback properties.
            var socket = client.createSocket(host: nil, port: nil, ssl: nil, socketAdapter: nil)

            socket.onError = { [weak self] error in
                self?.onError?("\(error)")
            }
            socket.onMatchData = { [weak self] matchData in
                self?.handleMatchData(opCode: Int(matchData.opCode), data: [UInt8](matchData.data))
            }
            socket.onMatchmakerMatched = { [weak self] matched in
                Task { await self?.joinMatch(matched) }
            }
            socket.onConnect = { [weak self] in
                Task { await self?.enterMatchmaking() }
            }

            self.socket = socket
            socket.connect(session: session, appearOnline: nil)
        } catch {
            onError?("\(error)")
        }
    }

    private func enterMatchmaking() async {
        do {
            onStatus?("Finding opponent...")
            _ = try await socket?.addMatchmaker(query: "*", minCount: 2, maxCount: 2, stringProperties: nil, numericProperties: nil, countMultiple: nil)
        } catch {
            onError?("\(error)")
        }
    }

    private func joinMatch(_ matched: Nakama_Realtime_MatchmakerMatched) async {
        do {
            onStatus?("Match found, joining...")
            guard let socket = socket else { return }
            let match: Nakama_Realtime_Match
            if !matched.matchID.isEmpty {
                match = try await socket.joinMatch(matchId: matched.matchID, metadata: nil)
            } else if !matched.token.isEmpty {
                match = try await socket.joinMatchToken(token: matched.token)
            } else {
                onError?("matchmaker returned no match id or token")
                return
            }
            self.matchId = match.matchID
            self.transport = NakamaTransport(socket: socket, matchId: match.matchID)
            onStatus?("Waiting for opponent...")
        } catch {
            onError?("\(error)")
        }
    }

    private func handleMatchData(opCode: Int, data: [UInt8]) {
        switch opCode {
        case MatchOpCode.start:
            handleStart(data: data)
        case MatchOpCode.input:
            transport?.ingest(data: data)
        default:
            break
        }
    }

    private struct StartPayload: Decodable {
        let seed: Int64
        let order: [String]
        let loadouts: [CosmeticLoadout]?
    }

    private func handleStart(data: [UInt8]) {
        guard !didStart else { return }
        guard let session = nakamaSession,
              let transport = transport,
              let payload = try? JSONDecoder().decode(StartPayload.self, from: Data(data)),
              let slot = payload.order.firstIndex(of: session.userId) else {
            onError?("bad start payload")
            return
        }
        didStart = true
        let seed = UInt64(bitPattern: payload.seed)
        let rollback = RollbackSession(localPlayer: slot, transport: transport, config: .default, seed: seed)
        // Loadouts are aligned with order (index == player slot).
        var loadouts = payload.loadouts ?? []
        while loadouts.count < payload.order.count { loadouts.append(.default) }
        onStatus?("Match starting...")
        onReady?(rollback, loadouts)
    }

    func leave() {
        let socket = self.socket
        let id = self.matchId
        Task {
            if let socket = socket, let id = id {
                try? await socket.leaveMatch(matchId: id)
            }
            socket?.disconnect()
        }
    }
}
