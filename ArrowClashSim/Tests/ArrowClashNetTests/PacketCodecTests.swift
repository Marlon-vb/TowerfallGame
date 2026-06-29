import XCTest
@testable import ArrowClashNet
import ArrowClashSim

final class PacketCodecTests: XCTestCase {

    func testRoundTrip() {
        let packet = InputPacket(
            player: 1,
            startFrame: 123456,
            inputs: [
                InputCommand(buttons: [.left, .jump], aim: 0),
                InputCommand(buttons: [.right, .dash, .shoot], aim: 200),
                InputCommand(buttons: [], aim: 255),
            ]
        )
        let bytes = PacketCodec.encode(packet)
        let decoded = PacketCodec.decode(bytes)
        XCTAssertEqual(decoded, packet)
    }

    func testEmptyInputs() {
        let packet = InputPacket(player: 0, startFrame: 0, inputs: [])
        let decoded = PacketCodec.decode(PacketCodec.encode(packet))
        XCTAssertEqual(decoded, packet)
    }

    func testRejectsTruncatedData() {
        XCTAssertNil(PacketCodec.decode([0, 1, 2]))           // too short for header
        XCTAssertNil(PacketCodec.decode([0, 0, 0, 0, 0, 5, 0])) // claims 5 inputs, has none
    }
}
