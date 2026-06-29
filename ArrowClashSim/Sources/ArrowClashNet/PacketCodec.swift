// PacketCodec.swift
// Compact binary encoding for InputPacket on the wire. The server relays these
// bytes opaquely; only clients encode/decode them. Uses [UInt8] (no Foundation)
// so it stays portable and unit-testable; the transport converts to/from Data at
// the SDK boundary.
//
// Layout (little-endian):
//   u8  player
//   i32 startFrame
//   u16 count
//   count * (u8 buttons, u8 aim)

public enum PacketCodec {

    public static func encode(_ packet: InputPacket) -> [UInt8] {
        var out: [UInt8] = []
        out.reserveCapacity(7 + packet.inputs.count * 2)
        out.append(UInt8(truncatingIfNeeded: packet.player))
        let sf = Int32(truncatingIfNeeded: packet.startFrame)
        out.append(UInt8(truncatingIfNeeded: sf))
        out.append(UInt8(truncatingIfNeeded: sf >> 8))
        out.append(UInt8(truncatingIfNeeded: sf >> 16))
        out.append(UInt8(truncatingIfNeeded: sf >> 24))
        let count = UInt16(truncatingIfNeeded: packet.inputs.count)
        out.append(UInt8(truncatingIfNeeded: count))
        out.append(UInt8(truncatingIfNeeded: count >> 8))
        for cmd in packet.inputs {
            out.append(cmd.buttons.rawValue)
            out.append(cmd.aim)
        }
        return out
    }

    public static func decode(_ bytes: [UInt8]) -> InputPacket? {
        guard bytes.count >= 7 else { return nil }
        let player = Int(bytes[0])
        let sf = Int32(bytes[1])
            | (Int32(bytes[2]) << 8)
            | (Int32(bytes[3]) << 16)
            | (Int32(bytes[4]) << 24)
        let count = Int(UInt16(bytes[5]) | (UInt16(bytes[6]) << 8))
        guard bytes.count == 7 + count * 2 else { return nil }

        var inputs: [InputCommand] = []
        inputs.reserveCapacity(count)
        var i = 7
        for _ in 0..<count {
            let buttons = InputCommand.Buttons(rawValue: bytes[i])
            let aim = bytes[i + 1]
            inputs.append(InputCommand(buttons: buttons, aim: aim))
            i += 2
        }
        return InputPacket(player: player, startFrame: Int(sf), inputs: inputs)
    }
}
