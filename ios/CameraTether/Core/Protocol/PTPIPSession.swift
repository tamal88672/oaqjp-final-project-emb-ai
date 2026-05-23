import Foundation

struct PTPObjectInfo: Sendable {
    let objectHandle: UInt32
    let storageID: UInt32
    let objectFormat: UInt16
    let objectCompressedSize: UInt32
    let filename: String
    let captureDate: Date?
}

actor PTPIPSession {
    private let host: String
    private let port: UInt16
    private var commandChannel: PTPIPCommandChannel?
    private var eventChannel: PTPIPEventChannel?
    private var ptpIPSessionID: UInt32 = 0
    private let ptpSessionID: UInt32 = 1
    private let guid = UUID()
    private(set) var isOpen = false

    private var newObjectContinuation: AsyncStream<UInt32>.Continuation?
    private(set) lazy var newObjectStream: AsyncStream<UInt32> = AsyncStream { [weak self] cont in
        Task { await self?.setObjectContinuation(cont) }
    }

    init(host: String, port: UInt16 = 15740) {
        self.host = host
        self.port = port
    }

    func open() async throws {
        let cmd = PTPIPCommandChannel(host: host, port: port)
        try await cmd.connect()
        let sessionID = try await cmd.performHandshake(guid: guid, hostname: "CameraTether")
        ptpIPSessionID = sessionID
        commandChannel = cmd

        let evt = PTPIPEventChannel(host: host, port: port)
        try await evt.connect()
        try await evt.performHandshake(sessionID: sessionID)
        eventChannel = evt

        let openResp = try await cmd.sendOperation(
            code: .openSession,
            params: [ptpSessionID]
        )
        guard openResp.code == .ok || openResp.code == .sessionAlreadyOpen else {
            throw PTPIPError.sessionError(openResp.code)
        }

        isOpen = true
        Task { await listenForEvents() }
    }

    func close() async throws {
        guard isOpen, let cmd = commandChannel else { return }
        _ = try? await cmd.sendOperation(code: .closeSession)
        commandChannel?.disconnect()
        eventChannel?.disconnect()
        commandChannel = nil
        eventChannel = nil
        isOpen = false
        newObjectContinuation?.finish()
    }

    func fetchObject(handle: UInt32) async throws -> (info: PTPObjectInfo, data: Data) {
        guard let cmd = commandChannel else { throw PTPIPError.connectionLost }

        let infoResp = try await cmd.sendOperation(code: .getObjectInfo, params: [handle])
        guard infoResp.code == .ok, let infoData = infoResp.data else {
            throw PTPIPError.transferError("GetObjectInfo failed: \(infoResp.code)")
        }
        let info = parseObjectInfo(handle: handle, data: infoData)

        let objResp = try await cmd.sendOperation(code: .getObject, params: [handle])
        guard objResp.code == .ok, let objData = objResp.data else {
            throw PTPIPError.transferError("GetObject failed: \(objResp.code)")
        }
        return (info: info, data: objData)
    }

    func listObjectHandles(storageID: UInt32 = 0xFFFFFFFF) async throws -> [UInt32] {
        guard let cmd = commandChannel else { throw PTPIPError.connectionLost }
        let resp = try await cmd.sendOperation(
            code: .getObjectHandles,
            params: [storageID, 0, 0]
        )
        guard resp.code == .ok, let data = resp.data else {
            return []
        }
        return parseHandleArray(data: data)
    }

    // MARK: - Private

    private func setObjectContinuation(_ cont: AsyncStream<UInt32>.Continuation) {
        newObjectContinuation = cont
    }

    private func listenForEvents() async {
        guard let evt = eventChannel else { return }
        for await event in evt.eventStream {
            if event.code == .objectAdded {
                newObjectContinuation?.yield(event.param1)
            }
        }
        newObjectContinuation?.finish()
    }

    private func parseObjectInfo(handle: UInt32, data: Data) -> PTPObjectInfo {
        guard data.count >= 52 else {
            return PTPObjectInfo(objectHandle: handle, storageID: 0, objectFormat: 0,
                                 objectCompressedSize: 0, filename: "unknown", captureDate: nil)
        }
        let storageID   = data.loadLE(UInt32.self, at: 0)
        let format      = data.loadLE(UInt16.self, at: 4)
        let size        = data.loadLE(UInt32.self, at: 8)
        let (filename, _) = data.readUTF16LEString(from: 52)
        return PTPObjectInfo(
            objectHandle: handle,
            storageID: storageID,
            objectFormat: format,
            objectCompressedSize: size,
            filename: filename,
            captureDate: Date()
        )
    }

    private func parseHandleArray(data: Data) -> [UInt32] {
        guard data.count >= 4 else { return [] }
        let count = Int(data.loadLE(UInt32.self, at: 0))
        var handles: [UInt32] = []
        handles.reserveCapacity(count)
        for i in 0..<count {
            let offset = 4 + i * 4
            guard offset + 3 < data.count else { break }
            handles.append(data.loadLE(UInt32.self, at: offset))
        }
        return handles
    }
}
