import Foundation

enum ConnectionState: Equatable, Sendable {
    case disconnected
    case discovering
    case connecting(host: String)
    case connected(device: CameraDevice)
    case transferring(progress: Double)
    case reconnecting(attempt: Int)
    case error(message: String)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var connectedDevice: CameraDevice? {
        if case .connected(let device) = self { return device }
        return nil
    }

    var statusText: String {
        switch self {
        case .disconnected:             return "Not connected"
        case .discovering:              return "Searching for cameras…"
        case .connecting(let host):     return "Connecting to \(host)…"
        case .connected(let device):    return "Connected to \(device.displayName)"
        case .transferring(let p):      return "Transferring \(Int(p * 100))%"
        case .reconnecting(let n):      return "Reconnecting (attempt \(n))…"
        case .error(let msg):           return "Error: \(msg)"
        }
    }
}
