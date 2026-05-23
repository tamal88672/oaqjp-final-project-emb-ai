import Foundation
import CoreImage

struct MaskLayer: Identifiable, Sendable {
    let id: UUID
    var type: MaskType
    var maskImageData: Data?           // serializable grayscale PNG of the mask
    var invertMask: Bool = false
    var featherRadius: Float = 0
    var associatedEdit: EditState
    var isVisible: Bool = true

    init(id: UUID = UUID(), type: MaskType, associatedEdit: EditState = EditState()) {
        self.id = id
        self.type = type
        self.associatedEdit = associatedEdit
    }
}

enum MaskType: Sendable {
    case person
    case sky
    case colorRange(targetHue: Float, hueTolerance: Float)
    case luminosity(low: Float, high: Float, smoothing: Float)
    case gradient(startX: Float, startY: Float, endX: Float, endY: Float, radial: Bool)
    case brush
}

enum GradientType: Sendable {
    case linear, radial, reflected
}

struct BrushStroke: Identifiable, Sendable {
    let id: UUID
    var points: [CGPoint]
    var radius: Float
    var hardness: Float      // 0 = soft, 1 = hard
    var opacity: Float
    var isErasing: Bool

    init(
        id: UUID = UUID(),
        points: [CGPoint] = [],
        radius: Float = 20,
        hardness: Float = 0.5,
        opacity: Float = 1.0,
        isErasing: Bool = false
    ) {
        self.id = id
        self.points = points
        self.radius = radius
        self.hardness = hardness
        self.opacity = opacity
        self.isErasing = isErasing
    }
}

struct BrushSettings: Sendable {
    var radius: Float = 20
    var hardness: Float = 0.5
    var opacity: Float = 1.0
    var isErasing: Bool = false
}
