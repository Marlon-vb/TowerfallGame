// NakamaTransport.swift
// Adapts a Nakama realtime socket to the rollback layer's InputTransport. The
// server relays our OpInput packets to the opponent; we encode/decode them with
// PacketCodec. This is the ONLY rollback-facing Nakama code besides the
// controller, so if the Nakama Swift SDK API differs from what is used here,
// the fixes are confined to this file and OnlineMatchController.
//
// NOTE: not compiled in this environment (no iOS toolchain / Nakama SDK here).
// Method/type names follow the documented nakama-swift async API and may need
// small adjustments to match your resolved SDK version.

import Foundation
import ArrowClashSim
import ArrowClashNet
import Nakama

enum MatchOpCode {
    static let start: Int64 = 1
    static let input: Int64 = 2
}

final class NakamaTransport: InputTransport {
    private let socket: Socket
    private let matchId: String
    private let lock = NSLock()
    private var inbound: [InputPacket] = []

    init(socket: Socket, matchId: String) {
        self.socket = socket
        self.matchId = matchId
    }

    // Called by the controller's match-data callback for OpInput messages.
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
            try? await socket.sendMatchData(matchId: id, opCode: MatchOpCode.input, data: Data(bytes))
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
