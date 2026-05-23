import Foundation

struct EditState: Equatable, Codable, Sendable {
    var exposure: Float = 0          // -2.0 to +2.0 EV
    var highlights: Float = 0        // -100 to +100
    var shadows: Float = 0           // -100 to +100
    var whites: Float = 0            // -100 to +100
    var blacks: Float = 0            // -100 to +100
    var temperature: Float = 0       // -100 to +100 (kelvin offset)
    var tint: Float = 0              // -100 to +100
    var saturation: Float = 1.0      // 0.0 to 2.0
    var vibrance: Float = 0          // -100 to +100
    var sharpness: Float = 0         // 0.0 to 1.0
    var noiseReduction: Float = 0    // 0.0 to 1.0
    var clarity: Float = 0           // -100 to +100
    var preset: AutoEditPreset = .none
    var autoAdjustApplied: Bool = false

    static let identity = EditState()
}
