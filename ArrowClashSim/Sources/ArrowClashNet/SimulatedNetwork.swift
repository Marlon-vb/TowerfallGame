// SimulatedNetwork.swift
// In-process link between two transports for offline rollback testing and the
// local two-player rollback demo. Delivery is delayed by a base latency plus
// optional jitter, and packets are dropped at a configurable rate. All of it is
// driven by a seeded PRNG so a run is reproducible given its seed.
//
// Time is measured in frames. Call advance() once per simulated frame after both
// endpoints have stepped, to move the clock forward and let delayed packets
// arrive.

import ArrowClashSim

public final class SimulatedNetwork {

    public final class Endpoint: InputTransport {
        fileprivate weak var net: SimulatedNetwork?
        fileprivate let index: Int
        fileprivate var inbox: [(deliverAt: Int, packet: InputPacket)] = []

        fileprivate init(index: Int) { self.index = index }

        public func send(_ packet: InputPacket) {
            net?.route(from: index, packet)
        }

        public func poll() -> [InputPacket] {
            guard let net = net else { return [] }
            let now = net.now
            var ready: [InputPacket] = []
            var remaining: [(deliverAt: Int, packet: InputPacket)] = []
            for entry in inbox {
                if entry.deliverAt <= now {
                    ready.append(entry.packet)
                } else {
                    remaining.append(entry)
                }
            }
            inbox = remaining
            return ready
        }
    }

    public private(set) var now: Int = 0
    private let latency: Int
    private let jitter: Int
    private let lossPerThousand: UInt32
    private var rng: DeterministicRandom

    public let endpointA: Endpoint
    public let endpointB: Endpoint

    public init(latency: Int, jitter: Int = 0, lossPerThousand: UInt32 = 0, seed: UInt64) {
        self.latency = latency
        self.jitter = jitter
        self.lossPerThousand = lossPerThousand
        self.rng = DeterministicRandom(seed: seed)
        self.endpointA = Endpoint(index: 0)
        self.endpointB = Endpoint(index: 1)
        self.endpointA.net = self
        self.endpointB.net = self
    }

    public func advance() {
        now += 1
    }

    private func route(from index: Int, _ packet: InputPacket) {
        // Drop?
        if lossPerThousand > 0 && rng.next(upperBound: 1000) < lossPerThousand {
            return
        }
        var delay = latency
        if jitter > 0 {
            delay += Int(rng.next(upperBound: UInt32(jitter + 1)))
        }
        let target = (index == 0) ? endpointB : endpointA
        target.inbox.append((deliverAt: now + delay, packet: packet))
    }
}
