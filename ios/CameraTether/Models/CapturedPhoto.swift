import Foundation
import CoreImage

struct CapturedPhoto: Identifiable, Sendable {
    let id: UUID
    let rawData: Data
    let filename: String
    let captureDate: Date
    let source: PhotoSource
    let format: ImageFormat
    var editedImageData: Data?
    var editState: EditState
    var maskLayers: [MaskLayer]
    var localIdentifier: String?
    var thumbnail: Data?

    init(
        id: UUID = UUID(),
        rawData: Data,
        filename: String,
        captureDate: Date = Date(),
        source: PhotoSource,
        format: ImageFormat
    ) {
        self.id = id
        self.rawData = rawData
        self.filename = filename
        self.captureDate = captureDate
        self.source = source
        self.format = format
        self.editState = EditState()
        self.maskLayers = []
    }
}

enum PhotoSource: String, Sendable, Codable {
    case wifi, usb, builtIn
}

enum ImageFormat: String, Sendable, Codable {
    case jpeg, tiff, rawCR3, rawNEF, rawARW, rawGeneric

    var isRAW: Bool {
        switch self {
        case .rawCR3, .rawNEF, .rawARW, .rawGeneric: return true
        default: return false
        }
    }

    static func from(ptpObjectFormat: UInt16) -> ImageFormat {
        switch ptpObjectFormat {
        case 0x3801: return .jpeg
        case 0x3807: return .tiff
        default:     return .rawGeneric
        }
    }

    static func from(filename: String) -> ImageFormat {
        switch filename.pathExtension.lowercased() {
        case "cr3", "cr2": return .rawCR3
        case "nef":        return .rawNEF
        case "arw":        return .rawARW
        case "jpg", "jpeg": return .jpeg
        case "tiff", "tif": return .tiff
        default:           return .rawGeneric
        }
    }
}

private extension String {
    var pathExtension: String {
        (self as NSString).pathExtension
    }
}
