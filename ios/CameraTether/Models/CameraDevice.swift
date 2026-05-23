import Foundation

struct CameraDevice: Identifiable, Equatable, Sendable {
    let id: UUID
    let displayName: String
    let vendor: CameraVendor
    let connectionType: ConnectionType
    let hostAddress: String?
    let port: UInt16

    static func builtIn() -> CameraDevice {
        CameraDevice(
            id: UUID(),
            displayName: "iPhone Camera",
            vendor: .apple,
            connectionType: .builtIn,
            hostAddress: nil,
            port: 0
        )
    }
}

enum CameraVendor: String, Equatable, Sendable, CaseIterable {
    case canon, nikon, sony, fujifilm, olympus, apple, unknown

    var displayName: String {
        switch self {
        case .canon:    return "Canon"
        case .nikon:    return "Nikon"
        case .sony:     return "Sony"
        case .fujifilm: return "FUJIFILM"
        case .olympus:  return "OM System"
        case .apple:    return "Apple"
        case .unknown:  return "Unknown"
        }
    }

    static func from(bonjourName: String) -> CameraVendor {
        let lower = bonjourName.lowercased()
        if lower.contains("canon")    { return .canon }
        if lower.contains("nikon")    { return .nikon }
        if lower.contains("sony")     { return .sony }
        if lower.contains("fuji")     { return .fujifilm }
        if lower.contains("olympus") || lower.contains("om system") { return .olympus }
        return .unknown
    }
}

enum ConnectionType: String, Equatable, Sendable {
    case wifi, usb, builtIn
}
