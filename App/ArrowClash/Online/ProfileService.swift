// ProfileService.swift
// Reads and updates progression via Nakama's HTTP REST API using URLSession.
//
// Why not the Nakama Swift SDK here: in nakama-swift v1.2.0 the response models
// expose their payload/value with `internal` access, so an app module cannot
// read RPC results or storage values through the SDK. The HTTP API returns plain
// JSON we control. The realtime match still uses the SDK socket (its MatchData
// is readable). Auth uses the same device id as the match path, so both map to
// the same Nakama user.
//
// The server owns all progression writes; these RPCs only trigger server-side
// computation and return the resulting profile JSON.

import Foundation

@MainActor
final class ProfileService: ObservableObject {
    @Published var profile: PlayerProfile?
    @Published var statusText: String = ""

    var serverHost: String = "127.0.0.1"
    var httpPort: Int = 7350
    var serverKey: String = "defaultkey"
    var useSSL: Bool = false

    private let auth: AuthProvider
    private var token: String?

    init(auth: AuthProvider = DeviceAuthProvider()) {
        self.auth = auth
    }

    private var baseURL: String {
        "\(useSSL ? "https" : "http")://\(serverHost):\(httpPort)"
    }

    // Drop the cached session (e.g. after the server host changes).
    func reset() {
        token = nil
    }

    // MARK: Public API

    func refresh() async {
        do {
            profile = try await rpcProfile("get_profile", innerPayload: nil)
        } catch {
            statusText = "\(error)"
        }
    }

    private struct MatchEndRequest: Encodable {
        let matchId: String
        let won: Bool
        let kills: Int
        let rounds: Int
    }

    func submitMatchEnd(matchId: String, won: Bool, kills: Int, rounds: Int) async {
        do {
            let inner = try jsonString(MatchEndRequest(matchId: matchId, won: won, kills: kills, rounds: rounds))
            profile = try await rpcProfile("match_end", innerPayload: inner)
        } catch {
            statusText = "\(error)"
        }
    }

    @discardableResult
    func setAvatar(_ avatar: Avatar) async -> Bool {
        do {
            let inner = try jsonString(avatar)
            profile = try await rpcProfile("set_avatar", innerPayload: inner)
            return true
        } catch {
            statusText = "\(error)"
            return false
        }
    }

    private struct PurchaseRequest: Encodable { let itemId: String }

    @discardableResult
    func purchase(_ itemId: String) async -> Bool {
        do {
            let inner = try jsonString(PurchaseRequest(itemId: itemId))
            profile = try await rpcProfile("purchase", innerPayload: inner)
            return true
        } catch {
            statusText = "\(error)"
            return false
        }
    }

    // MARK: Leaderboard

    struct LeaderboardEntry: Identifiable, Equatable {
        let id: String
        let rank: Int
        let username: String
        let score: Int
    }

    @Published var leaderboard: [LeaderboardEntry] = []

    // The ranked ladder (ELO ratings, server-written only).
    func refreshLeaderboard(limit: Int = 25) async {
        do {
            let token = try await ensureToken()
            guard let url = URL(string: "\(baseURL)/v2/leaderboard/arrowclash_rating?limit=\(limit)") else {
                throw NakamaHTTPError.badServerHost
            }
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (data, response) = try await URLSession.shared.data(for: req)
            try Self.checkOK(response, data)
            let decoded = try JSONDecoder().decode(LeaderboardResponse.self, from: data)
            leaderboard = (decoded.records ?? []).map { record in
                LeaderboardEntry(id: record.owner_id ?? UUID().uuidString,
                                 rank: Int(record.rank ?? "0") ?? 0,
                                 username: (record.username?.isEmpty == false ? record.username! : "archer"),
                                 score: Int(record.score ?? "0") ?? 0)
            }
        } catch {
            statusText = "\(error)"
        }
    }

    // Nakama's protobuf-JSON encodes int64 fields as strings.
    private struct LeaderboardResponse: Decodable {
        let records: [LeaderboardRecord]?
    }
    private struct LeaderboardRecord: Decodable {
        let owner_id: String?
        let username: String?
        let score: String?
        let rank: String?
    }

    // MARK: HTTP plumbing

    private func ensureToken() async throws -> String {
        if let token = token { return token }
        // The host comes from a free-form settings field; never force-unwrap.
        guard let url = URL(string: "\(baseURL)/v2/account/authenticate/device?create=true") else {
            throw NakamaHTTPError.badServerHost
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        let basic = Data("\(serverKey):".utf8).base64EncodedString()
        req.setValue("Basic \(basic)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["id": auth.identifier()])

        let (data, response) = try await URLSession.shared.data(for: req)
        try Self.checkOK(response, data)
        let decoded = try JSONDecoder().decode(AuthResponse.self, from: data)
        token = decoded.token
        return decoded.token
    }

    // Calls an RPC and decodes the returned profile JSON. Retries once after
    // re-authenticating if the cached session token has expired (HTTP 401).
    private func rpcProfile(_ id: String, innerPayload: String?) async throws -> PlayerProfile {
        do {
            return try await rpcProfileOnce(id, innerPayload: innerPayload)
        } catch NakamaHTTPError.server(401, _) {
            token = nil
            return try await rpcProfileOnce(id, innerPayload: innerPayload)
        }
    }

    private func rpcProfileOnce(_ id: String, innerPayload: String?) async throws -> PlayerProfile {
        let token = try await ensureToken()
        guard let url = URL(string: "\(baseURL)/v2/rpc/\(id)") else {
            throw NakamaHTTPError.badServerHost
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Nakama's REST RPC expects the payload as a JSON-encoded string in the body.
        let bodyString = innerPayload ?? ""
        req.httpBody = try JSONEncoder().encode(bodyString)

        let (data, response) = try await URLSession.shared.data(for: req)
        try Self.checkOK(response, data)
        let envelope = try JSONDecoder().decode(RpcEnvelope.self, from: data)
        guard let payloadData = envelope.payload.data(using: .utf8) else {
            throw NakamaHTTPError.badPayload
        }
        return try JSONDecoder().decode(PlayerProfile.self, from: payloadData)
    }

    private func jsonString<T: Encodable>(_ value: T) throws -> String {
        let data = try JSONEncoder().encode(value)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private static func checkOK(_ response: URLResponse, _ data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw NakamaHTTPError.server(http.statusCode, message)
        }
    }

    private struct AuthResponse: Decodable { let token: String }
    private struct RpcEnvelope: Decodable { let payload: String }
}

enum NakamaHTTPError: Error {
    case badPayload
    case badServerHost
    case server(Int, String)
}
