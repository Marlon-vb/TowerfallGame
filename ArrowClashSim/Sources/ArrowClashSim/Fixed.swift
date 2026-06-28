// Fixed.swift
// Q16.16 fixed-point number used for ALL gameplay math.
// No floats in gameplay logic. The only float conversion (toFloat) is for
// rendering and must never be used inside the simulation.
//
// Layout: a 32-bit signed integer where the low 16 bits are the fraction.
//   value = raw / 65536
// Range is roughly +/- 32768 with 1/65536 precision, which is plenty for a
// small arena measured in pixels. Multiplication uses a 64-bit intermediate
// to avoid loss, and truncatingIfNeeded is used so behavior is identical in
// debug and release builds (no overflow traps that could differ).

public struct Fixed: Equatable, Comparable, Hashable {
    public static let fractionalBits: Int = 16
    public static let scale: Int64 = 1 << 16

    public var raw: Int32

    @inlinable
    public init(raw: Int32) {
        self.raw = raw
    }

    // Whole-number initializer. Intended for small magnitudes (arena pixels).
    @inlinable
    public init(_ value: Int) {
        self.raw = Int32(value << Fixed.fractionalBits)
    }

    // Exact fraction initializer, e.g. Fixed(numerator: 1, denominator: 2) == 0.5.
    @inlinable
    public init(numerator: Int, denominator: Int) {
        let n = Int64(numerator) << Fixed.fractionalBits
        self.raw = Int32(truncatingIfNeeded: n / Int64(denominator))
    }

    public static let zero = Fixed(raw: 0)
    public static let one = Fixed(raw: Int32(Fixed.scale))

    // Floor toward negative infinity, returned as an Int pixel value.
    // Arithmetic right shift floors for two's complement integers.
    @inlinable
    public var floorToInt: Int {
        return Int(raw >> Fixed.fractionalBits)
    }

    // Render-only conversion. Do NOT call this from gameplay logic.
    @inlinable
    public var toFloat: Float {
        return Float(raw) / Float(Fixed.scale)
    }

    @inlinable
    public var magnitude: Fixed {
        return Fixed(raw: raw < 0 ? -raw : raw)
    }

    // Comparable
    @inlinable
    public static func < (lhs: Fixed, rhs: Fixed) -> Bool {
        return lhs.raw < rhs.raw
    }

    // Arithmetic
    @inlinable
    public static prefix func - (value: Fixed) -> Fixed {
        return Fixed(raw: -value.raw)
    }

    @inlinable
    public static func + (lhs: Fixed, rhs: Fixed) -> Fixed {
        return Fixed(raw: lhs.raw &+ rhs.raw)
    }

    @inlinable
    public static func - (lhs: Fixed, rhs: Fixed) -> Fixed {
        return Fixed(raw: lhs.raw &- rhs.raw)
    }

    @inlinable
    public static func * (lhs: Fixed, rhs: Fixed) -> Fixed {
        let product = (Int64(lhs.raw) * Int64(rhs.raw)) >> Fixed.fractionalBits
        return Fixed(raw: Int32(truncatingIfNeeded: product))
    }

    @inlinable
    public static func / (lhs: Fixed, rhs: Fixed) -> Fixed {
        let numerator = Int64(lhs.raw) << Fixed.fractionalBits
        return Fixed(raw: Int32(truncatingIfNeeded: numerator / Int64(rhs.raw)))
    }

    @inlinable
    public static func += (lhs: inout Fixed, rhs: Fixed) {
        lhs = lhs + rhs
    }

    @inlinable
    public static func -= (lhs: inout Fixed, rhs: Fixed) {
        lhs = lhs - rhs
    }

    @inlinable
    public static func clamp(_ value: Fixed, min lower: Fixed, max upper: Fixed) -> Fixed {
        if value.raw < lower.raw { return lower }
        if value.raw > upper.raw { return upper }
        return value
    }
}
