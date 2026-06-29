// NakamaTransport.swift
// Adapts a Nakama realtime socket to the rollback layer's InputTransport. The
// server relays our OpInput packets to the opponent; we encode/decode them with
// PacketCodec. This plus OnlineMatchController are the only Nakama-SDK-facing
// files, so SDK changes stay contained here.
//
// Written against nakama-swift v1.2.0.

import Foundation
import ArrowClashSim
import ArrowClashNet
import Nakama

enum MatchOpCode {
    // sendMatchData takes opCode: Int in this SDK.
    static let start: Int = 1
    static let input: Int = 2
}

final class NakamaTransport: InputTransport {
    private let socket: SocketProtocol
    private let matchId: String
    private let lock = NSLock()
    private var inbound: [InputPacket] = []

    init(socket: SocketProtocol, matchId: String) {
        self.socket = socket
        self.matchId = matchId
    }

    // Called by the controller's onMatchData handler for OpInput messages.
    func ingest(data: [UInt8]) {
        guard let packet = PacketCodec.decode(data) else { return }
        lock.lock()
        inbound.append(packet)
        lock.unlock()
    }

    // InputTransport.send is synchronous; the SDK send is async, so fire and
    // forget. Inputs are sent in a redundant window, so a missed send is
    // recovered by the next one.
    func send(_ packet: InputPacket) {
        let bytes = PacketCodec.encode(packet)
        let id = matchId
        let socket = self.socket
        Task {
            try? await socket.sendMatchData(matchId: id, opCode: MatchOpCode.input, data: Data(bytes), presences: nil)
        }
    }

    func poll() -> [InputPacket] {
        lock.lock()
        let out = inbound
        inbound.removeAll(keepingCapacity: true)
        lock.unlock()
        return out
    }
}
