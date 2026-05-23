import SwiftUI

struct PresetSelectorView: View {
    @EnvironmentObject var editVM: EditViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(AutoEditPreset.allCases) { preset in
                    PresetTile(
                        preset: preset,
                        isSelected: editVM.selectedPreset == preset
                    ) {
                        Task { await editVM.applyPreset(preset) }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

struct PresetTile: View {
    let preset: AutoEditPreset
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color(.tertiarySystemBackground))
                    .frame(width: 64, height: 64)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
                    .overlay(
                        Image(systemName: presetIcon(preset))
                            .foregroundColor(isSelected ? .accentColor : .secondary)
                    )
                Text(preset.rawValue)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .accentColor : .primary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    private func presetIcon(_ preset: AutoEditPreset) -> String {
        switch preset {
        case .none:      return "circle.slash"
        case .portrait:  return "person.fill"
        case .landscape: return "mountain.2.fill"
        case .street:    return "building.2.fill"
        case .product:   return "cube.box.fill"
        case .night:     return "moon.stars.fill"
        case .bw:        return "circle.lefthalf.filled"
        case .filmic:    return "film.fill"
        }
    }
}
