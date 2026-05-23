import SwiftUI

struct RetouchView: View {
    @EnvironmentObject var editVM: EditViewModel
    @State private var skinSmoothing: Float = 0
    @State private var eyeEnhancement: Float = 0
    @State private var teethWhitening: Float = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 2) {
                Text("Retouching")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                SliderRow(label: "Skin Smooth", value: skinSmoothing,
                          range: 0...1, format: ".2f") { v in
                    skinSmoothing = v
                }
                SliderRow(label: "Eye Enhance", value: eyeEnhancement,
                          range: 0...1, format: ".2f") { v in
                    eyeEnhancement = v
                }
                SliderRow(label: "Teeth", value: teethWhitening,
                          range: 0...1, format: ".2f") { v in
                    teethWhitening = v
                }

                Divider().padding(.vertical, 4)

                Text("Tools")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ToolChip(label: "Heal",    icon: "bandage",     isActive: editVM.activeTool == .heal)    { editVM.activeTool = .heal }
                        ToolChip(label: "Clone",   icon: "doc.on.doc",  isActive: editVM.activeTool == .clone)   { editVM.activeTool = .clone }
                        ToolChip(label: "Dodge",   icon: "sun.min",     isActive: false) {}
                        ToolChip(label: "Burn",    icon: "flame",       isActive: false) {}
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
        }
    }
}

struct ToolChip: View {
    let label: String
    let icon: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isActive ? Color.accentColor : Color(.tertiarySystemBackground))
                .foregroundColor(isActive ? .white : .primary)
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}
