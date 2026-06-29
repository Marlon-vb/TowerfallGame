// StateHash.swift
// FNV-1a 64-bit hash over every raw integer field of the game state, in a
// fixed order. Used to prove determinism (same inputs -> same hash) and, later,
// to detect rollback desyncs by comparing confirmed-tick hashes between peers.
//
// Only integer/raw fields are mixed in. No floats are ever hashed.

public func stateHash(_ state: GameState) -> UInt64 {
    var hash: UInt64 = 0xcbf29ce484222325
    let prime: UInt64 = 0x100000001b3

    func mix(_ value: UInt64) {
        hash = (hash ^ value) &* prime
    }
    func mix32(_ value: Int32) {
        mix(UInt64(UInt32(bitPattern: value)))
    }

    mix(UInt64(state.tick))
    mix(state.rng.state)
    mix(UInt64(state.players.count))

    for p in state.players {
        mix32(p.pos.x.raw)
        mix32(p.pos.y.raw)
        mix32(p.vel.x.raw)
        mix32(p.vel.y.raw)
        mix(UInt64(UInt8(bitPattern: p.facing)))
        mix(p.onGround ? 1 : 0)
        mix32(p.coyoteTimer)
        mix32(p.jumpBufferTimer)
        mix32(p.dashActiveTimer)
        mix32(p.dashCooldownTimer)
        mix(UInt64(p.prevButtons))
        mix(UInt64(bitPattern: Int64(p.arrows)))
    }

    mix(UInt64(state.arrows.count))
    for arrow in state.arrows {
        mix32(arrow.pos.x.raw)
        mix32(arrow.pos.y.raw)
        mix32(arrow.vel.x.raw)
        mix32(arrow.vel.y.raw)
        mix(arrow.active ? 1 : 0)
        mix(arrow.stuck ? 1 : 0)
        mix(UInt64(UInt8(bitPattern: arrow.owner)))
        mix(UInt64(arrow.dir))
    }

    return hash
}
