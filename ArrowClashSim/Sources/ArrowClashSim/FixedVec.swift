// FixedVec.swift
// 2D vector of Q16.16 fixed-point values. Plain value type.

public struct FixedVec: Equatable, Hashable {
    public var x: Fixed
    public var y: Fixed

    @inlinable
    public init(x: Fixed, y: Fixed) {
        self.x = x
        self.y = y
    }

    public static let zero = FixedVec(x: .zero, y: .zero)

    @inlinable
    public static func + (lhs: FixedVec, rhs: FixedVec) -> FixedVec {
        return FixedVec(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    @inlinable
    public static func - (lhs: FixedVec, rhs: FixedVec) -> FixedVec {
        return FixedVec(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }
}
