import Foundation

struct PTPIPPacket {
    let type: PTPIPPacketType
    let payload: Data

    // Wire format: [UInt32 length LE][UInt32 type LE][payload]
    // Length field includes itself (4) + type field (4) + payload.
    var wireData: Data {
        let totalLength = UInt32(8 + payload.count)
        var result = Data(capacity: Int(totalLength))
        result.appendLE(totalLength)
        result.appendLE(type.rawValue)
        result.append(payload)
        return result
    }

    // Parses the first complete packet from buffer.
    // Returns (packet, remainingData) or nil if buffer is incomplete.
    static func parse(from buffer: Data) throws -> (PTPIPPacket, Data)? {
        guard buffer.count >= 8 else { return nil }
        let length = buffer.loadLE(UInt32.self, at: 0)
        guard length >= 8 else {
            throw PTPIPError.malformedPacket("Packet length \(length) < 8")
        }
        guard buffer.count >= Int(length) else { return nil }
        let rawType = buffer.loadLE(UInt32.self, at: 4)
        guard let type = PTPIPPacketType(rawValue: rawType) else {
            throw PTPIPError.unknownPacketType(rawType)
        }
        let payload = buffer.subdata(in: 8..<Int(length))
        let remaining = buffer.subdata(in: Int(length)..<buffer.count)
        return (PTPIPPacket(type: type, payload: payload), remaining)
    }

    // Convenience builders
    static func initCommandRequest(guid: UUID, name: String) -> PTPIPPacket {
        var payload = Data()
        payload.append(guid.uuidBytes)
        payload.appendUTF16LEString(name)
        payload.appendLE(UInt32(0x00010000)) // version 1.0
        return PTPIPPacket(type: .initCommandRequest, payload: payload)
    }

    static func initEventRequest(sessionID: UInt32) -> PTPIPPacket {
        var payload = Data()
        payload.appendLE(sessionID)
        return PTPIPPacket(type: .initEventRequest, payload: payload)
    }

    static func probeResponse() -> PTPIPPacket {
        PTPIPPacket(type: .probeResponse, payload: Data())
    }
}

enum PTPIPError: Error, LocalizedError {
    case malformedPacket(String)
    case unknownPacketType(UInt32)
    case handshakeFailed(String)
    case sessionError(PTPResponseCode)
    case transferError(String)
    case connectionLost

    var errorDescription: String? {
        switch self {
        case .malformedPacket(let msg):    return "Malformed PTP/IP packet: \(msg)"
        case .unknownPacketType(let t):    return "Unknown PTP/IP packet type: 0x\(String(t, radix: 16))"
        case .handshakeFailed(let msg):    return "PTP/IP handshake failed: \(msg)"
        case .sessionError(let code):      return "PTP session error: \(code)"
        case .transferError(let msg):      return "Transfer error: \(msg)"
        case .connectionLost:              return "Camera connection lost"
        }
    }
}

// MARK: - Data helpers

extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        var le = value.littleEndian
        append(UnsafeBufferPointer(start: &le, count: 1))
    }

    func loadLE<T: FixedWidthInteger>(_ type: T.Type, at offset: Int) -> T {
        var value: T = 0
        _ = Swift.withUnsafeMutableBytes(of: &value) { ptr in
            self.copyBytes(to: ptr, from: offset..<(offset + MemoryLayout<T>.size))
        }
        return T(littleEndian: value)
    }

    mutating func appendUTF16LEString(_ string: String) {
        for scalar in (string + "\0").unicodeScalars {
            appendLE(UInt16(scalar.value & 0xFFFF))
        }
    }

    func readUTF16LEString(from offset: Int) -> (String, Int) {
        var chars: [UInt16] = []
        var i = offset
        while i + 1 < count {
            let c = loadLE(UInt16.self, at: i)
            i += 2
            if c == 0 { break }
            chars.append(c)
        }
        return (String(decoding: chars, as: UTF16.self), i)
    }
}

extension UUID {
    var uuidBytes: Data {
        withUnsafeBytes(of: uuid) { Data($0) }
    }
}
