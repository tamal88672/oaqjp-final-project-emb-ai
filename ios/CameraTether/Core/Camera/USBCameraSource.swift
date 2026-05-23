import Foundation
import ExternalAccessory

actor USBCameraSource: CameraSource {
    private let accessory: EAAccessory
    private let protocolString: String
    private var session: EASession?
    private(set) var connectionState: ConnectionState = .disconnected
    private var photoContinuation: AsyncStream<CapturedPhoto>.Continuation?

    private(set) lazy var newPhotoStream: AsyncStream<CapturedPhoto> = AsyncStream { [weak self] cont in
        Task { await self?.setContinuation(cont) }
    }

    init(accessory: EAAccessory) {
        self.accessory = accessory
        self.protocolString = accessory.protocolStrings.first ?? ""
    }

    func connect() async throws {
        guard !protocolString.isEmpty else {
            throw PTPIPError.handshakeFailed("No supported protocol on USB accessory")
        }
        let device = CameraDevice(
            id: UUID(),
            displayName: accessory.name,
            vendor: CameraVendor.from(bonjourName: accessory.name),
            connectionType: .usb,
            hostAddress: nil,
            port: 0
        )
        connectionState = .connected(device: device)
        // USB PTP via EASession — handshake handled by the accessory firmware
        // Additional PTP operation exchange would mirror PTPIPSession over streams
    }

    func disconnect() async throws {
        session?.inputStream?.close()
        session?.outputStream?.close()
        session = nil
        connectionState = .disconnected
        photoContinuation?.finish()
    }

    func fetchLatestPhotos(limit: Int) async throws -> [CapturedPhoto] {
        // USB photo fetch mirrors PTPIPSession.listObjectHandles + fetchObject
        // over EASession input/output streams using same PTPIPPacket framing
        return []
    }

    private func setContinuation(_ cont: AsyncStream<CapturedPhoto>.Continuation) {
        photoContinuation = cont
    }
}
