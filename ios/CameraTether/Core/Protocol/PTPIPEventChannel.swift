import Foundation
import Network

struct PTPEvent: Sendable {
    let code: PTPEventCode
    let transactionID: UInt32
    let param1: UInt32
    let param2: UInt32
    let param3: UInt32
}

actor PTPIPEventChannel {
    private let connection: NWConnection
    private var receiveBuffer = Data()
    private var continuation: AsyncStream<PTPEvent>.Continuation?

    private(set) lazy var eventStream: AsyncStream<PTPEvent> = AsyncStream { [weak self] cont in
        Task { await self?.setContinuation(cont) }
    }

    init(host: String, port: UInt16 = 15740) {
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port)!
        )
        self.connection = NWConnection(to: endpoint, using: .tcp)
    }

    func connect() async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:   cont.resume()
                case .failed(let e): cont.resume(throwing: e)
                case .cancelled:     cont.resume(throwing: PTPIPError.connectionLost)
                default: break
                }
            }
            connection.start(queue: .global(qos: .userInitiated))
        }
    }

    func performHandshake(sessionID: UInt32) async throws {
        let packet = PTPIPPacket.initEventRequest(sessionID: sessionID)
        try await send(data: packet.wireData)
        try await waitForEventAck()
        receiveLoop()
    }

    func disconnect() {
        continuation?.finish()
        connection.cancel()
    }

    private func setContinuation(_ cont: AsyncStream<PTPEvent>.Continuation) {
        continuation = cont
    }

    private func waitForEventAck() async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
                Task { [weak self] in
                    guard let self else { return }
                    if let error { cont.resume(throwing: error); return }
                    if let data { await self.appendToBuffer(data) }
                    do {
                        if let (packet, remaining) = try PTPIPPacket.parse(from: await self.receiveBuffer) {
                            await self.setBuffer(remaining)
                            if packet.type == .initEventAck {
                                cont.resume()
                            } else {
                                cont.resume(throwing: PTPIPError.handshakeFailed("Expected initEventAck, got \(packet.type)"))
                            }
                        } else {
                            cont.resume(throwing: PTPIPError.handshakeFailed("Incomplete ack"))
                        }
                    } catch {
                        cont.resume(throwing: error)
                    }
                }
            }
        }
    }

    private func receiveLoop() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            Task { [weak self] in
                guard let self else { return }
                guard error == nil, !isComplete else {
                    await self.continuation?.finish()
                    return
                }
                if let data { await self.appendToBuffer(data) }
                await self.processBuffer()
                await self.receiveLoop()
            }
        }
    }

    private func appendToBuffer(_ data: Data) {
        receiveBuffer.append(data)
    }

    private func setBuffer(_ data: Data) {
        receiveBuffer = data
    }

    private func processBuffer() {
        do {
            while let (packet, remaining) = try PTPIPPacket.parse(from: receiveBuffer) {
                receiveBuffer = remaining
                handlePacket(packet)
            }
        } catch {}
    }

    private func handlePacket(_ packet: PTPIPPacket) {
        switch packet.type {
        case .event:
            guard packet.payload.count >= 10 else { return }
            let rawCode = packet.payload.loadLE(UInt16.self, at: 0)
            let txID    = packet.payload.loadLE(UInt32.self, at: 2)
            let p1 = packet.payload.count >= 10 ? packet.payload.loadLE(UInt32.self, at: 6)  : 0
            let p2 = packet.payload.count >= 14 ? packet.payload.loadLE(UInt32.self, at: 10) : 0
            let p3 = packet.payload.count >= 18 ? packet.payload.loadLE(UInt32.self, at: 14) : 0
            let code = PTPEventCode(rawValue: rawCode) ?? .unreported
            let event = PTPEvent(code: code, transactionID: txID, param1: p1, param2: p2, param3: p3)
            continuation?.yield(event)

        case .probeRequest:
            Task { try? await send(data: PTPIPPacket.probeResponse().wireData) }

        default:
            break
        }
    }

    private func send(data: Data) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error { cont.resume(throwing: error) }
                else { cont.resume() }
            })
        }
    }
}
