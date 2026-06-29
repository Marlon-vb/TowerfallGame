// OnlineMatchController.swift
// Drives the online path: device auth -> matchmaking -> join match -> receive
// the START (slot + shared seed) -> build a RollbackSession fed by a
// NakamaTransport. Auth is behind a tiny seam so Game Center could replace
// device id later.
//
// NOTE: not compiled in this environment (no iOS toolchain / Nakama SDK here).
// The Nakama Swift SDK API (client/socket method and property names, async
// shape) is the most likely thing to need small adjustments to match your
// resolved SDK version. All such usage is confined to this file and
// NakamaTransport.swift.

import Foundation
import ArrowClashSim
import ArrowClashNet
import Nakama

protocol AuthProvider {
    // Returns a stable identifier for this device/account.
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
    var onReady: ((RollbackSession) -> Void)?
    var onError: ((String) -> Void)?

    private let auth: AuthProvider
    private var client: Client?
    private var socket: Socket?
    private var nakamaSession: Session?
    private var transport: NakamaTransport?
    private var matchId: String?
    private var didStart = false

    init(auth: AuthProvider = DeviceAuthProvider()) {
        self.auth = auth
    }

    func start() {
        Task { await run() }
    }

    private func run() async {
        do {
            onStatus?("Connecting...")
            let client = GrpcClient(serverKey: serverKey, host: serverHost, port: serverPort, ssl: useSSL)
            self.client = client

            let session = try await client.authenticateDevice(id: auth.identifier())
            self.nakamaSession = session

            let socket = client.createSocket()
            self.socket = socket
            try await socket.connect(session: session)

            socket.onMatchData = { [weak self] matchData in
                self?.handleMatchData(opCode: matchData.opCode, data: [UInt8](matchData.data))
            }
            socket.onMatchmakerMatched = { [weak self] matched in
                Task { await self?.joinMatch(matched) }
            }

            onStatus?("Finding opponent...")
            _ = try await socket.addMatchmaker(query: "*", minCount: 2, maxCount: 2, stringProperties: nil, numericProperties: nil)
        } catch {
            onError?("\(error)")
        }
    }

    private func joinMatch(_ matched: MatchmakerMatched) async {
        do {
            onStatus?("Match found, joining...")
            guard let socket = socket else { return }
            let match: Match
            if let id = matched.matchId {
                match = try await socket.joinMatch(matchId: id)
            } else if let token = matched.token {
                match = try await socket.joinMatch(token: token)
            } else {
                onError?("matchmaker returned no match id")
                return
            }
            self.matchId = match.matchId
            self.transport = NakamaTransport(socket: socket, matchId: match.matchId)
            onStatus?("Waiting for opponent to be ready...")
        } catch {
            onError?("\(error)")
        }
    }

    private func handleMatchData(opCode: Int64, data: [UInt8]) {
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
        onStatus?("Match starting...")
        onReady?(rollback)
    }

    func leave() {
        let socket = self.socket
        let id = self.matchId
        Task {
            if let socket = socket, let id = id {
                try? await socket.leaveMatch(matchId: id)
            }
            try? await socket?.disconnect()
        }
    }
}
