import XCTest
@testable import CameraTether

final class PTPIPPacketTests: XCTestCase {

    // MARK: - Serialization

    func testWireDataLength() {
        let payload = Data([0xAA, 0xBB, 0xCC])
        let packet = PTPIPPacket(type: .cmdRequest, payload: payload)
        XCTAssertEqual(packet.wireData.count, 8 + 3) // header + payload
    }

    func testWireDataEmptyPayload() {
        let packet = PTPIPPacket(type: .probeResponse, payload: Data())
        XCTAssertEqual(packet.wireData.count, 8)
        // Length field (LE) should be 8
        let length = packet.wireData.loadLE(UInt32.self, at: 0)
        XCTAssertEqual(length, 8)
    }

    func testWireDataLittleEndian() {
        let packet = PTPIPPacket(type: .event, payload: Data())
        let wire = packet.wireData
        // Type field at offset 4 should be 0x00000008 in LE = [0x08, 0x00, 0x00, 0x00]
        XCTAssertEqual(wire[4], 0x08)
        XCTAssertEqual(wire[5], 0x00)
        XCTAssertEqual(wire[6], 0x00)
        XCTAssertEqual(wire[7], 0x00)
    }

    // MARK: - Parsing

    func testParseRoundTrip() throws {
        let payload = Data([1, 2, 3, 4, 5])
        let original = PTPIPPacket(type: .cmdResponse, payload: payload)
        let wire = original.wireData
        let result = try PTPIPPacket.parse(from: wire)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.0.type, .cmdResponse)
        XCTAssertEqual(result?.0.payload, payload)
        XCTAssertEqual(result?.1.count, 0) // no remaining bytes
    }

    func testParsePartialReturnsNil() throws {
        let payload = Data([1, 2, 3, 4, 5])
        let packet = PTPIPPacket(type: .cmdRequest, payload: payload)
        let wire = packet.wireData.prefix(6) // only 6 of 13 bytes
        let result = try PTPIPPacket.parse(from: Data(wire))
        XCTAssertNil(result)
    }

    func testParseInsufficientForHeader() throws {
        let result = try PTPIPPacket.parse(from: Data([0x00, 0x01]))
        XCTAssertNil(result)
    }

    func testParseReturnsRemainder() throws {
        let p1 = PTPIPPacket(type: .probeRequest,  payload: Data([0xAA]))
        let p2 = PTPIPPacket(type: .probeResponse, payload: Data([0xBB]))
        let combined = p1.wireData + p2.wireData
        let result = try PTPIPPacket.parse(from: combined)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.0.type, .probeRequest)
        XCTAssertEqual(result?.1, p2.wireData)
    }

    func testParseMalformedLengthThrows() {
        var wire = Data(count: 8)
        // Write length = 3 (less than minimum 8)
        wire[0] = 3; wire[1] = 0; wire[2] = 0; wire[3] = 0
        XCTAssertThrowsError(try PTPIPPacket.parse(from: wire))
    }

    // MARK: - Handshake builders

    func testInitCommandRequestContainsName() {
        let guid = UUID()
        let packet = PTPIPPacket.initCommandRequest(guid: guid, name: "TestHost")
        XCTAssertEqual(packet.type, .initCommandRequest)
        // Payload: 16 (guid) + name UTF16LE + null + 4 (version)
        // "TestHost" = 8 chars × 2 bytes + 2 bytes null = 18 bytes; 16+18+4 = 38
        XCTAssertEqual(packet.payload.count, 38)
    }

    func testInitEventRequestContainsSessionID() {
        let sessionID: UInt32 = 0xDEADBEEF
        let packet = PTPIPPacket.initEventRequest(sessionID: sessionID)
        XCTAssertEqual(packet.type, .initEventRequest)
        XCTAssertEqual(packet.payload.count, 4)
        XCTAssertEqual(packet.payload.loadLE(UInt32.self, at: 0), sessionID)
    }

    // MARK: - Data helpers

    func testDataLoadLE() {
        var data = Data(count: 4)
        data[0] = 0x01; data[1] = 0x02; data[2] = 0x03; data[3] = 0x04
        let value = data.loadLE(UInt32.self, at: 0)
        XCTAssertEqual(value, 0x04030201)
    }

    func testDataAppendLE() {
        var data = Data()
        data.appendLE(UInt32(0x01020304))
        XCTAssertEqual(data, Data([0x04, 0x03, 0x02, 0x01]))
    }

    func testUTF16LEStringRoundTrip() {
        var data = Data()
        data.appendUTF16LEString("Hello")
        let (result, _) = data.readUTF16LEString(from: 0)
        XCTAssertEqual(result, "Hello")
    }
}
