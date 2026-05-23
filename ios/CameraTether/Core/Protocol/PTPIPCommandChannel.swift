import Foundation
import Network

struct PTPResponse {
    let code: PTPResponseCode
    let transactionID: UInt32
    let params: [UInt32]
    let data: Data?
}

actor PTPIPCommandChannel {
    private let connection: NWConnection
    private var receiveBuffer = Data()
    private var transactionID: UInt32 = 1
    private var pendingContinuations: [UInt32: CheckedContinuation<PTPResponse, Error>] = [:]
    private var dataAccumulator: (totalSize: UInt64, buffer: Data, transactionID: UInt32)?

    init(host: String, port: UInt16 = 15740) {
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port)!
        )
        let params = NWParameters.tcp
        params.defaultProtocolStack.transportProtocol
            .map { ($0 as? NWProtocolTCP.Options) }?
            .map { $0?.noDelay = true }
        self.connection = NWConnection(to: endpoint, using: params)
    }

    func connect() async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            connection.stateUpdateHandler = { [weak self] state in
                Task { [weak self] in
                    switch state {
                    case .ready:
                        cont.resume()
                        await self?.startReceiving()
                    case .failed(let error):
                        cont.resume(throwing: error)
                    case .cancelled:
                        cont.resume(throwing: PTPIPError.connectionLost)
                    default:
                        break
                    }
                }
            }
            connection.start(queue: .global(qos: .userInitiated))
        }
    }

    func performHandshake(guid: UUID, hostname: String) async throws -> UInt32 {
        let initPacket = PTPIPPacket.initCommandRequest(guid: guid, name: hostname)
        try await send(data: initPacket.wireData)

        return try await withCheckedThrowingContinuation { cont in
            waitForHandshakeAck(continuation: cont)
        }
    }

    private func waitForHandshakeAck(continuation: CheckedContinuation<UInt32, Error>) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            Task { [weak self] in
                guard let self else { return }
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if let data { await self.appendToBuffer(data) }
                await self.processHandshakeBuffer(continuation: continuation)
            }
        }
    }

    private func processHandshakeBuffer(continuation: CheckedContinuation<UInt32, Error>) {
        do {
            while let (packet, remaining) = try PTPIPPacket.parse(from: receiveBuffer) {
                receiveBuffer = remaining
                if packet.type == .initCommandAck {
                    guard packet.payload.count >= 4 else {
                        continuation.resume(throwing: PTPIPError.handshakeFailed("Invalid ack payload"))
                        return
                    }
                    let sessionID = packet.payload.loadLE(UInt32.self, at: 0)
                    continuation.resume(returning: sessionID)
                    return
                } else if packet.type == .initFail {
                    continuation.resume(throwing: PTPIPError.handshakeFailed("Camera rejected connection"))
                    return
                }
            }
            // Need more data
            waitForHandshakeAck(continuation: continuation)
        } catch {
            continuation.resume(throwing: error)
        }
    }

    func sendOperation(
        code: PTPOperationCode,
        params: [UInt32] = [],
        data: Data? = nil
    ) async throws -> PTPResponse {
        let txID = nextTransactionID()
        var payload = Data()
        payload.appendLE(UInt32(data != nil ? 1 : 0)) // data phase flag
        payload.appendLE(code.rawValue)
        payload.appendLE(txID)
        for p in params { payload.appendLE(p) }

        let cmdPacket = PTPIPPacket(type: .cmdRequest, payload: payload)
        try await send(data: cmdPacket.wireData)

        if let data {
            try await sendDataPhase(data: data, transactionID: txID)
        }

        return try await withCheckedThrowingContinuation { cont in
            pendingContinuations[txID] = cont
        }
    }

    private func sendDataPhase(data: Data, transactionID: UInt32) async throws {
        // StartData
        var startPayload = Data()
        startPayload.appendLE(transactionID)
        startPayload.appendLE(UInt64(data.count))
        try await send(data: PTPIPPacket(type: .startData, payload: startPayload).wireData)

        // Data (single chunk for simplicity)
        var dataPayload = Data()
        dataPayload.appendLE(transactionID)
        dataPayload.append(data)
        try await send(data: PTPIPPacket(type: .data, payload: dataPayload).wireData)

        // EndData
        var endPayload = Data()
        endPayload.appendLE(transactionID)
        try await send(data: PTPIPPacket(type: .endData, payload: endPayload).wireData)
    }

    func disconnect() {
        connection.cancel()
    }

    // MARK: - Private

    private func nextTransactionID() -> UInt32 {
        let id = transactionID
        transactionID = (transactionID == UInt32.max) ? 1 : transactionID + 1
        return id
    }

    private func appendToBuffer(_ data: Data) {
        receiveBuffer.append(data)
    }

    private func send(data: Data) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error { cont.resume(throwing: error) }
                else { cont.resume() }
            })
        }
    }

    private func startReceiving() {
        receiveLoop()
    }

    private func receiveLoop() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            Task { [weak self] in
                guard let self else { return }
                if let error {
                    await self.failAllPending(error: error)
                    return
                }
                if let data { await self.appendToBuffer(data) }
                await self.processBuffer()
                if !isComplete { await self.receiveLoop() }
            }
        }
    }

    private func processBuffer() {
        do {
            while let (packet, remaining) = try PTPIPPacket.parse(from: receiveBuffer) {
                receiveBuffer = remaining
                handlePacket(packet)
            }
        } catch {
            failAllPending(error: error)
        }
    }

    private func handlePacket(_ packet: PTPIPPacket) {
        switch packet.type {
        case .startData:
            guard packet.payload.count >= 12 else { return }
            let txID = packet.payload.loadLE(UInt32.self, at: 0)
            let totalSize = packet.payload.loadLE(UInt64.self, at: 4)
            dataAccumulator = (totalSize: totalSize, buffer: Data(capacity: Int(min(totalSize, 50_000_000))), transactionID: txID)

        case .data:
            guard packet.payload.count >= 4,
                  var acc = dataAccumulator else { return }
            let txID = packet.payload.loadLE(UInt32.self, at: 0)
            guard txID == acc.transactionID else { return }
            acc.buffer.append(packet.payload.subdata(in: 4..<packet.payload.count))
            dataAccumulator = acc

        case .endData:
            // Data phase complete; wait for CmdResponse to resolve continuation
            break

        case .cmdResponse:
            guard packet.payload.count >= 6 else { return }
            let rawCode = packet.payload.loadLE(UInt16.self, at: 0)
            let txID = packet.payload.loadLE(UInt32.self, at: 2)
            let code = PTPResponseCode(rawValue: rawCode) ?? .generalError
            var params: [UInt32] = []
            var offset = 6
            while offset + 3 < packet.payload.count {
                params.append(packet.payload.loadLE(UInt32.self, at: offset))
                offset += 4
            }
            let accData = (dataAccumulator?.transactionID == txID) ? dataAccumulator?.buffer : nil
            dataAccumulator = nil
            let response = PTPResponse(code: code, transactionID: txID, params: params, data: accData)
            pendingContinuations.removeValue(forKey: txID)?.resume(returning: response)

        case .probeRequest:
            Task {
                try? await send(data: PTPIPPacket.probeResponse().wireData)
            }

        default:
            break
        }
    }

    private func failAllPending(error: Error) {
        let pending = pendingContinuations
        pendingContinuations.removeAll()
        for cont in pending.values {
            cont.resume(throwing: error)
        }
    }
}
