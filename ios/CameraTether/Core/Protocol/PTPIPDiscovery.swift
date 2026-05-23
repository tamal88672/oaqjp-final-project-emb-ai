import Foundation
import Network

struct DiscoveredCamera: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let host: String
    let port: UInt16
    let vendor: CameraVendor

    func toCameraDevice() -> CameraDevice {
        CameraDevice(id: id, displayName: name, vendor: vendor, connectionType: .wifi, hostAddress: host, port: port)
    }
}

@MainActor
final class PTPIPDiscovery: ObservableObject {
    @Published private(set) var discoveredCameras: [DiscoveredCamera] = []

    private var browser: NWBrowser?
    private let queue = DispatchQueue(label: "ptp.discovery", qos: .utility)

    func startBrowsing() {
        guard browser == nil else { return }
        let params = NWParameters()
        params.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjourWithTXTRecord(type: "_ptp._tcp", domain: "local."), using: params)
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor [weak self] in
                await self?.handleResults(results)
            }
        }
        browser.start(queue: queue)
        self.browser = browser
    }

    func stopBrowsing() {
        browser?.cancel()
        browser = nil
    }

    private func handleResults(_ results: Set<NWBrowser.Result>) async {
        var cameras: [DiscoveredCamera] = []
        for result in results {
            if let camera = await resolve(result: result) {
                cameras.append(camera)
            }
        }
        discoveredCameras = cameras
    }

    private func resolve(result: NWBrowser.Result) async -> DiscoveredCamera? {
        guard case .service(let name, _, _, _) = result.endpoint else { return nil }
        var txtName = name
        var vendor = CameraVendor.from(bonjourName: name)
        if case .bonjour(let txt) = result.metadata {
            if let ty = txt.dictionary["ty"] {
                txtName = ty
                vendor = CameraVendor.from(bonjourName: ty)
            }
        }
        // Resolve host address
        guard let (host, port) = await resolveEndpoint(result.endpoint) else { return nil }
        return DiscoveredCamera(id: UUID(), name: txtName, host: host, port: port, vendor: vendor)
    }

    private func resolveEndpoint(_ endpoint: NWEndpoint) async -> (String, UInt16)? {
        return await withCheckedContinuation { cont in
            let connection = NWConnection(to: endpoint, using: .tcp)
            var resumed = false
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if case .hostPort(let host, let port) = connection.currentPath?.remoteEndpoint {
                        if !resumed {
                            resumed = true
                            cont.resume(returning: ("\(host)", port.rawValue))
                        }
                    }
                    connection.cancel()
                case .failed, .cancelled:
                    if !resumed {
                        resumed = true
                        cont.resume(returning: nil)
                    }
                default: break
                }
            }
            connection.start(queue: .global())
            // Timeout after 5 seconds
            DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                if !resumed {
                    resumed = true
                    connection.cancel()
                    cont.resume(returning: nil)
                }
            }
        }
    }
}
