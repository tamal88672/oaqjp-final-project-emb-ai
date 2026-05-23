import SwiftUI

struct AdjustmentPanelView: View {
    @EnvironmentObject var editVM: EditViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 2) {
                SliderRow(label: "Exposure",    value: editVM.editState.exposure,
                          range: -2...2,        format: "+.1f") { v in
                    Task { await editVM.updateExposure(v) }
                }
                SliderRow(label: "Highlights",  value: editVM.editState.highlights / 100,
                          range: -1...1,        format: ".0f", scale: 100) { v in
                    Task { await editVM.updateHighlights(v * 100) }
                }
                SliderRow(label: "Shadows",     value: editVM.editState.shadows / 100,
                          range: -1...1,        format: ".0f", scale: 100) { v in
                    Task { await editVM.updateShadows(v * 100) }
                }
                SliderRow(label: "Temperature", value: editVM.editState.temperature / 100,
                          range: -1...1,        format: ".0f", scale: 100) { v in
                    Task { await editVM.updateWhiteBalance(temp: v * 100, tint: editVM.editState.tint) }
                }
                SliderRow(label: "Saturation",  value: editVM.editState.saturation - 1,
                          range: -1...1,        format: ".2f") { v in
                    Task { await editVM.updateSaturation(v + 1) }
                }
                SliderRow(label: "Clarity",     value: editVM.editState.clarity / 100,
                          range: -1...1,        format: ".0f", scale: 100) { v in
                    Task { await editVM.updateClarity(v * 100) }
                }
                SliderRow(label: "Sharpness",   value: editVM.editState.sharpness,
                          range: 0...1,         format: ".2f") { v in
                    Task { await editVM.updateSharpness(v) }
                }
                SliderRow(label: "Noise Reduction", value: editVM.editState.noiseReduction,
                          range: 0...1,         format: ".2f") { v in
                    Task { await editVM.updateNoise(v) }
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

struct SliderRow: View {
    let label: String
    let value: Float
    let range: ClosedRange<Float>
    let format: String
    var scale: Float = 1
    let onChange: (Float) -> Void

    @State private var localValue: Float

    init(label: String, value: Float, range: ClosedRange<Float>,
         format: String, scale: Float = 1, onChange: @escaping (Float) -> Void) {
        self.label = label
        self.value = value
        self.range = range
        self.format = format
        self.scale = scale
        self.onChange = onChange
        self._localValue = State(initialValue: value)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .frame(width: 90, alignment: .leading)
                .foregroundColor(.secondary)
            Slider(value: $localValue, in: range)
                .onChange(of: localValue) { onChange($0) }
            Text(displayValue)
                .font(.caption.monospacedDigit())
                .frame(width: 36, alignment: .trailing)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .onChange(of: value) { localValue = $0 }
    }

    private var displayValue: String {
        let v = localValue * scale
        if format.contains(".0f") { return "\(Int(v))" }
        return String(format: "%\(format)", v)
    }
}
