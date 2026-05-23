import Foundation
import CoreImage

struct EditOperation: Identifiable, Equatable, Sendable {
    let id: UUID
    var type: EditOperationType
    var parameters: EditState
    var maskLayerID: UUID?      // nil = global adjustment
    var isEnabled: Bool = true
    var opacity: Float = 1.0

    init(
        id: UUID = UUID(),
        type: EditOperationType,
        parameters: EditState = EditState(),
        maskLayerID: UUID? = nil
    ) {
        self.id = id
        self.type = type
        self.parameters = parameters
        self.maskLayerID = maskLayerID
    }
}

enum EditOperationType: String, Sendable, Equatable {
    case toneAndColor
    case maskedAdjustment
    case retouchHeal
    case retouchClone
    case retouchDodgeBurn
    case personEnhancement
    case autoEdit
}
