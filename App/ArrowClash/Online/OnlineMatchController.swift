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
    var onReady: ((RollbackSession, [Avatar], MapDefinition) -> Void)?
    var onError: ((String) -> Void)?

    private let auth: AuthProvider
    private var client: GrpcClient?
    private var socket: SocketProtocol?
    private var nakamaSession: Session?
    private var transport: NakamaTransport?
    private(set) var matchId: String?
    private var didStart = false
    // START received before joinMatch resumed (the server can broadcast START in
    // the same join processing that acks our join); replayed once joined.
    private var pendingStart: [UInt8]?
    // Guards the mutable state above: it is written from Task executors and the
    // socket callback thread.
    private let stateLock = NSLock()

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
            stateLock.lock()
            self.matchId = match.matchID
            self.transport = NakamaTransport(socket: socket, matchId: match.matchID)
            let buffered = pendingStart
            pendingStart = nil
            stateLock.unlock()
            onStatus?("Waiting for opponent...")
            // If START raced ahead of our join ack, process it now.
            if let buffered = buffered {
                handleStart(data: buffered)
            }
        } catch {
            onError?("\(error)")
        }
    }

    private func handleMatchData(opCode: Int, data: [UInt8]) {
        switch opCode {
        case MatchOpCode.start:
            handleStart(data: data)
        case MatchOpCode.input:
            stateLock.lock()
            let transport = self.transport
            stateLock.unlock()
            transport?.ingest(data: data)
        default:
            break
        }
    }

    private struct StartPayload: Decodable {
        let seed: Int64
        let order: [String]
        let avatars: [Avatar]?
        let mapId: Int?
    }

    private func handleStart(data: [UInt8]) {
        stateLock.lock()
        if didStart {
            stateLock.unlock()
            return
        }
        // START can arrive before joinMatch resumes and sets the transport;
        // buffer it instead of failing (joinMatch replays it once ready).
        guard let session = nakamaSession, let transport = transport else {
            pendingStart = data
            stateLock.unlock()
            return
        }
        guard let payload = try? JSONDecoder().decode(StartPayload.self, from: Data(data)),
              let slot = payload.order.firstIndex(of: session.userId) else {
            stateLock.unlock()
            onError?("bad start payload")
            return
        }
        didStart = true
        stateLock.unlock()
        let seed = UInt64(bitPattern: payload.seed)
        let map = Maps.byID(payload.mapId ?? 0)
        let rollback = RollbackSession(localPlayer: slot, transport: transport, config: .default, seed: seed, map: map)
        // Avatars are aligned with order (index == player slot).
        var avatars = payload.avatars ?? []
        while avatars.count < payload.order.count { avatars.append(.default) }
        onStatus?("Match starting...")
        onReady?(rollback, avatars, map)
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
