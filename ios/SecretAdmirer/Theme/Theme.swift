import SwiftUI

/// Color tokens — keep this file in sync with `docs/color-palette.md`.
enum Theme {
    static let velvetNight  = Color(red: 0.102, green: 0.043, blue: 0.122)   // #1A0B1F
    static let midnightPlum = Color(red: 0.176, green: 0.106, blue: 0.239)   // #2D1B3D
    static let crimsonRose  = Color(red: 0.545, green: 0.082, blue: 0.220)   // #8B1538
    static let roseGold     = Color(red: 0.718, green: 0.431, blue: 0.475)   // #B76E79
    static let champagne    = Color(red: 0.831, green: 0.686, blue: 0.216)   // #D4AF37
    static let dustyBlush   = Color(red: 0.910, green: 0.773, blue: 0.773)   // #E8C5C5
    static let whisper      = Color(red: 0.961, green: 0.902, blue: 0.910)   // #F5E6E8
    static let shadowInk    = Color(red: 0.039, green: 0.016, blue: 0.063)   // #0A0410

    static let heroGradient = LinearGradient(
        colors: [crimsonRose, roseGold, champagne],
        startPoint: .topLeading,
        endPoint: .bottomTrailing)

    static let cardGradient = LinearGradient(
        colors: [midnightPlum, velvetNight],
        startPoint: .top,
        endPoint: .bottom)
}

struct PrimaryButtonStyle: ButtonStyle {
    var disabled: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Theme.heroGradient)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(disabled ? 0.5 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .shadow(color: Theme.shadowInk.opacity(0.6), radius: 10, y: 4)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.roseGold)
            .frame(maxWidth: .infinity, minHeight: 44)
            .overlay(
                RoundedRectangle(cornerRadius: 10).stroke(Theme.roseGold, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct VelvetFieldStyle: TextFieldStyle {
    // Custom TextFieldStyle requires the underscore body for legacy reasons.
    func _body(configuration: TextField<_Label>) -> some View {
        configuration
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Theme.shadowInk.opacity(0.6))
            .foregroundStyle(Theme.whisper)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.roseGold.opacity(0.3)))
    }
}
