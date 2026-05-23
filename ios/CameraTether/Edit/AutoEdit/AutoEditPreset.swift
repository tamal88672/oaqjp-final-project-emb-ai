import Foundation

enum AutoEditPreset: String, CaseIterable, Identifiable, Codable, Sendable {
    case none       = "Original"
    case portrait   = "Portrait"
    case landscape  = "Landscape"
    case street     = "Street"
    case product    = "Product"
    case night      = "Night"
    case bw         = "B&W"
    case filmic     = "Filmic"

    var id: String { rawValue }

    var baselineEdit: EditState {
        var s = EditState()
        switch self {
        case .none:
            break
        case .portrait:
            s.highlights    = -20
            s.shadows       = 10
            s.saturation    = 0.9
            s.sharpness     = 0.4
            s.noiseReduction = 0.2
        case .landscape:
            s.saturation    = 1.15
            s.vibrance      = 30
            s.highlights    = -30
            s.shadows       = 20
            s.clarity       = 20
            s.sharpness     = 0.5
        case .street:
            s.saturation    = 0.85
            s.clarity       = 25
            s.highlights    = -15
            s.shadows       = 15
            s.sharpness     = 0.55
        case .product:
            s.temperature   = -10
            s.highlights    = -10
            s.whites        = 10
            s.saturation    = 1.05
            s.sharpness     = 0.6
        case .night:
            s.exposure      = 0.5
            s.shadows       = 40
            s.noiseReduction = 0.6
            s.saturation    = 0.95
        case .bw:
            s.saturation    = 0
            s.clarity       = 30
            s.sharpness     = 0.5
        case .filmic:
            s.saturation    = 0.88
            s.highlights    = -25
            s.shadows       = 15
            s.vibrance      = 15
            s.clarity       = 10
        }
        s.preset = self
        return s
    }
}
