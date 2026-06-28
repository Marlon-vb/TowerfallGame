// DeterministicRandom.swift
// Seeded xorshift64 PRNG. It is part of the game state so any randomness the
// sim uses is reproducible and rolls back/forward with the rest of the state.
// Uses only shifts and xor, which never overflow-trap.
//
// Not used by movement in Phase 0, but it lives in the state now because the
// determinism contract requires that the only source of randomness in the sim
// is a seeded PRNG carried in the snapshot.

public struct DeterministicRandom: Equatable, Hashable {
    public var state: UInt64

    @inlinable
    public init(seed: UInt64) {
        // Avoid the all-zero state, which xorshift cannot escape.
        self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    @inlinable
    public mutating func nextU32() -> UInt32 {
        var x = state
        x ^= x << 13
        x ^= x >> 7
        x ^= x << 17
        state = x
        return UInt32(truncatingIfNeeded: x >> 32)
    }

    // Returns a value in 0 ..< bound (bound must be > 0).
    @inlinable
    public mutating func next(upperBound bound: UInt32) -> UInt32 {
        return nextU32() % bound
    }
}
