import SwiftUI

struct MaskingView: View {
    @EnvironmentObject var maskingVM: MaskingViewModel
    @EnvironmentObject var editVM: EditViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Mask type buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    MaskTypeButton(label: "Person", icon: "person.fill") {
                        Task { await maskingVM.generatePersonMask() }
                    }
                    MaskTypeButton(label: "Sky", icon: "cloud.fill") {
                        Task { await maskingVM.generateSkyMask() }
                    }
                    MaskTypeButton(label: "Luminosity", icon: "sun.max.fill") {
                        Task { await maskingVM.generateLuminosityMask(low: 0.5, high: 1.0) }
                    }
                    MaskTypeButton(label: "Gradient", icon: "rectangle.gradient") {
                        Task { await maskingVM.addGradientMask(startX: 0, startY: 1, endX: 0, endY: 0.5) }
                    }
                    MaskTypeButton(label: "Brush", icon: "paintbrush.fill") {
                        maskingVM.activeMaskType = .brush
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }

            Divider()

            // Layer list
            if maskingVM.maskLayers.isEmpty {
                Text("No masks yet. Add a mask above.")
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .padding()
            } else {
                List {
                    ForEach(maskingVM.maskLayers) { layer in
                        MaskLayerRow(layer: layer,
                            onToggle:   { maskingVM.toggleMaskVisibility(id: layer.id) },
                            onInvert:   { maskingVM.invertMask(id: layer.id) },
                            onDelete:   { maskingVM.removeMaskLayer(id: layer.id) }
                        )
                    }
                }
                .listStyle(.plain)
            }

            if maskingVM.isGeneratingMask {
                HStack { ProgressView(); Text("Generating mask…").font(.caption) }
                    .padding(8)
            }
        }
    }
}

struct MaskTypeButton: View {
    let label: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.title3)
                Text(label).font(.caption2)
            }
            .frame(width: 60, height: 52)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct MaskLayerRow: View {
    let layer: MaskLayer
    let onToggle: () -> Void
    let onInvert: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Button(action: onToggle) {
                Image(systemName: layer.isVisible ? "eye.fill" : "eye.slash.fill")
                    .foregroundColor(layer.isVisible ? .primary : .secondary)
            }
            Text(maskTypeLabel(layer.type))
                .font(.caption)
            Spacer()
            Button("Invert", action: onInvert).font(.caption).foregroundColor(.accentColor)
            Button(action: onDelete) { Image(systemName: "trash").foregroundColor(.red) }
        }
        .padding(.vertical, 4)
    }

    private func maskTypeLabel(_ type: MaskType) -> String {
        switch type {
        case .person:         return "Person"
        case .sky:            return "Sky"
        case .colorRange:     return "Color Range"
        case .luminosity:     return "Luminosity"
        case .gradient:       return "Gradient"
        case .brush:          return "Brush"
        }
    }
}
