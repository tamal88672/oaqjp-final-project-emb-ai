import Foundation
import UIKit
import CoreImage
import Combine

enum EditTool: String, CaseIterable {
    case none, adjust, mask, retouch, heal, clone, dodgeBurn
}

@MainActor
final class EditViewModel: ObservableObject {
    @Published var currentPhoto: CapturedPhoto?
    @Published var editState: EditState = EditState()
    @Published var previewImage: UIImage?
    @Published var isProcessing: Bool = false
    @Published var selectedPreset: AutoEditPreset = .none
    @Published var activeTool: EditTool = .none
    @Published var history: EditHistory = EditHistory()
    @Published var showBeforeAfter: Bool = false

    private let pipeline = EditPipeline()
    private var debounceTask: Task<Void, Never>?
    private let context: CIContext = {
        if let dev = MTLCreateSystemDefaultDevice() { return CIContext(mtlDevice: dev) }
        return CIContext()
    }()

    func loadPhoto(_ photo: CapturedPhoto) async {
        currentPhoto = photo
        editState = photo.editState
        selectedPreset = photo.editState.preset
        guard let data = photo.editedImageData ?? Optional(photo.rawData),
              let base = CIImage(data: data) else { return }
        await pipeline.setBase(base)
        await renderPreview()
    }

    func applyPreset(_ preset: AutoEditPreset) async {
        selectedPreset = preset
        editState = preset.baselineEdit
        await scheduleRender()
    }

    func updateExposure(_ ev: Float) async {
        editState.exposure = ev
        await scheduleRender()
    }

    func updateWhiteBalance(temp: Float, tint: Float) async {
        editState.temperature = temp
        editState.tint = tint
        await scheduleRender()
    }

    func updateSaturation(_ value: Float) async {
        editState.saturation = value
        await scheduleRender()
    }

    func updateHighlights(_ value: Float) async { editState.highlights = value; await scheduleRender() }
    func updateShadows(_ value: Float) async    { editState.shadows    = value; await scheduleRender() }
    func updateClarity(_ value: Float) async    { editState.clarity    = value; await scheduleRender() }
    func updateSharpness(_ value: Float) async  { editState.sharpness  = value; await scheduleRender() }
    func updateNoise(_ value: Float) async      { editState.noiseReduction = value; await scheduleRender() }

    func undo() {
        if let ops = history.undo() {
            Task { await renderWithOps(ops) }
        }
    }

    func redo() {
        if let ops = history.redo() {
            Task { await renderWithOps(ops) }
        }
    }

    func exportFinal() async -> UIImage? {
        isProcessing = true
        defer { isProcessing = false }
        guard let cgImage = await pipeline.render() else { return nil }
        return UIImage(cgImage: cgImage)
    }

    // MARK: - Private

    private func scheduleRender() async {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms debounce
            guard !Task.isCancelled else { return }
            await renderPreview()
        }
    }

    private func renderPreview() async {
        isProcessing = true
        let op = EditOperation(type: .toneAndColor, parameters: editState)
        if let result = await pipeline.apply(op) {
            let preview = await Task.detached(priority: .userInitiated) { [weak self, result] () -> UIImage? in
                guard let self, let cg = self.context.createCGImage(result, from: result.extent) else { return nil }
                return UIImage(cgImage: cg)
            }.value
            previewImage = preview
        }
        isProcessing = false
    }

    private func renderWithOps(_ ops: [EditOperation]) async {
        guard let last = ops.last else { return }
        editState = last.parameters
        await renderPreview()
    }
}
