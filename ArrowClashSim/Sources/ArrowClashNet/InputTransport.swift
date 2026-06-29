// InputTransport.swift
// Abstracts the wire that carries per-tick input packets between the two
// players. Phase 2 uses an in-process simulated link; Phase 3 swaps in a Nakama
// relayed-match transport that implements this same protocol. A future P2P
// (UDP/WebRTC) transport could replace the relay here to cut latency.
//
// Packets are intentionally redundant: each carries a sliding window of the
// sender's most recent inputs, so a dropped packet is recovered by the next one
// as long as consecutive losses stay within the window.

public struct InputPacket: Equatable {
    public var player: Int          // which player these inputs belong to
    public var startFrame: Int      // frame index of inputs[0]
    public var inputs: [InputCommand]

    public init(player: Int, startFrame: Int, inputs: [InputCommand]) {
        self.player = player
        self.startFrame = startFrame
        self.inputs = inputs
    }
}

public protocol InputTransport: AnyObject {
    // Send a packet of local inputs to the peer.
    func send(_ packet: InputPacket)
    // Return all packets that have arrived since the last poll.
    func poll() -> [InputPacket]
}
