import Foundation
import Combine
import ExternalAccessory

@MainActor
final class ConnectionViewModel: ObservableObject {
    @Published var connectionState: ConnectionState = .disconnected
    @Published var selectedConnectionType: ConnectionType = .wifi
    @Published var manualIPAddress: String = ""
    @Published var isScanning: Bool = false
    @Published var errorMessage: String?

    var discovery: PTPIPDiscovery?
    var coordinator: PhotoTransferCoordinator?

    private var activeSource: (any CameraSource)?
    private var cancellables = Set<AnyCancellable>()

    func startDiscovery() {
        isScanning = true
        connectionState = .discovering
        discovery?.startBrowsing()
    }

    func stopDiscovery() {
        isScanning = false
        discovery?.stopBrowsing()
        if case .discovering = connectionState {
            connectionState = .disconnected
        }
    }

    func connect(to camera: DiscoveredCamera) async {
        do {
            let source = PTPIPCameraSource(camera: camera)
            connectionState = .connecting(host: camera.host)
            try await source.connect()
            activeSource = source
            connectionState = await source.connectionState
            coordinator?.attach(source: source)
        } catch {
            connectionState = .error(message: error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    func connectManual(ip: String) async {
        let manualCamera = DiscoveredCamera(
            id: UUID(),
            name: "Camera (\(ip))",
            host: ip,
            port: 15740,
            vendor: .unknown
        )
        await connect(to: manualCamera)
    }

    func selectBuiltInCamera() {
        Task {
            let source = BuiltInCameraSource()
            do {
                try await source.connect()
                activeSource = source
                connectionState = await source.connectionState
                coordinator?.attach(source: source)
            } catch {
                connectionState = .error(message: error.localizedDescription)
            }
        }
    }

    func disconnect() async {
        coordinator?.detach()
        try? await activeSource?.disconnect()
        activeSource = nil
        connectionState = .disconnected
    }

    func connectUSBAccessory(_ accessory: EAAccessory) async {
        let source = USBCameraSource(accessory: accessory)
        do {
            try await source.connect()
            activeSource = source
            connectionState = await source.connectionState
            coordinator?.attach(source: source)
        } catch {
            connectionState = .error(message: error.localizedDescription)
        }
    }
}
