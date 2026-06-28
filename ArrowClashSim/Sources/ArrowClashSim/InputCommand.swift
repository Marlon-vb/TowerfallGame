// InputCommand.swift
// Compact per-tick input for one player. The sim advances purely as a function
// of (previous state, both players' InputCommand for that tick).
//
// buttons is a 5-bit field. aim is an 8-bit direction (256 steps around the
// circle) for arrow aiming. shoot and aim are defined now so the wire format is
// stable, but they are unused by the Phase 0 movement sim.

public struct InputCommand: Equatable, Hashable {
    public struct Buttons: OptionSet, Hashable {
        public let rawValue: UInt8
        @inlinable public init(rawValue: UInt8) { self.rawValue = rawValue }

        public static let left  = Buttons(rawValue: 1 << 0)
        public static let right = Buttons(rawValue: 1 << 1)
        public static let jump  = Buttons(rawValue: 1 << 2)
        public static let dash  = Buttons(rawValue: 1 << 3)
        public static let shoot = Buttons(rawValue: 1 << 4)
    }

    public var buttons: Buttons
    public var aim: UInt8

    @inlinable
    public init(buttons: Buttons = [], aim: UInt8 = 0) {
        self.buttons = buttons
        self.aim = aim
    }

    public static let neutral = InputCommand()
}
