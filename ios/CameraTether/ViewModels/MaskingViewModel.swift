import Foundation
import CoreImage
import UIKit

@MainActor
final class MaskingViewModel: ObservableObject {
    @Published private(set) var maskLayers: [MaskLayer] = []
    @Published var activeMaskType: MaskType?
    @Published var maskPreviewImage: UIImage?
    @Published var brushSettings: BrushSettings = BrushSettings()
    @Published var isGeneratingMask: Bool = false

    private var baseImage: CIImage?
    private var activeBrush: BrushMask?
    private var currentStroke: BrushStroke?
    private let context: CIContext = {
        if let dev = MTLCreateSystemDefaultDevice() { return CIContext(mtlDevice: dev) }
        return CIContext()
    }()

    func setBaseImage(_ image: CIImage) {
        baseImage = image
    }

    func generatePersonMask() async {
        guard let image = baseImage else { return }
        isGeneratingMask = true
        defer { isGeneratingMask = false }
        let generator = PersonSegmentationMask()
        if let maskCI = try? await generator.generateMask(for: image) {
            var layer = MaskLayer(type: .person)
            layer.maskImageData = toPNG(maskCI)
            maskLayers.append(layer)
            await renderPreview(mask: maskCI)
        }
    }

    func generateSkyMask() async {
        guard let image = baseImage else { return }
        isGeneratingMask = true
        defer { isGeneratingMask = false }
        let generator = SkyDetectionMask()
        if let maskCI = try? await generator.generateMask(for: image) {
            var layer = MaskLayer(type: .sky)
            layer.maskImageData = toPNG(maskCI)
            maskLayers.append(layer)
            await renderPreview(mask: maskCI)
        }
    }

    func generateColorMask(targetHue: Float, tolerance: Float = 0.1) async {
        guard let image = baseImage else { return }
        isGeneratingMask = true
        defer { isGeneratingMask = false }
        let generator = ColorRangeMask(targetHue: targetHue, hueTolerance: tolerance)
        if let maskCI = try? await generator.generateMask(for: image) {
            var layer = MaskLayer(type: .colorRange(targetHue: targetHue, hueTolerance: tolerance))
            layer.maskImageData = toPNG(maskCI)
            maskLayers.append(layer)
            await renderPreview(mask: maskCI)
        }
    }

    func generateLuminosityMask(low: Float, high: Float, smoothing: Float = 0.1) async {
        guard let image = baseImage else { return }
        isGeneratingMask = true
        defer { isGeneratingMask = false }
        let generator = LuminosityMask(low: low, high: high, smoothing: smoothing)
        if let maskCI = try? await generator.generateMask(for: image) {
            var layer = MaskLayer(type: .luminosity(low: low, high: high, smoothing: smoothing))
            layer.maskImageData = toPNG(maskCI)
            maskLayers.append(layer)
            await renderPreview(mask: maskCI)
        }
    }

    func addGradientMask(startX: Float, startY: Float, endX: Float, endY: Float, isRadial: Bool = false) async {
        guard let image = baseImage else { return }
        let start = CGPoint(x: CGFloat(startX), y: CGFloat(startY))
        let end   = CGPoint(x: CGFloat(endX),   y: CGFloat(endY))
        let generator = GradientMask(startPoint: start, endPoint: end, isRadial: isRadial)
        if let maskCI = try? await generator.generateMask(for: image) {
            let layerType = MaskType.gradient(startX: startX, startY: startY, endX: endX, endY: endY, radial: isRadial)
            var layer = MaskLayer(type: layerType)
            layer.maskImageData = toPNG(maskCI)
            maskLayers.append(layer)
            await renderPreview(mask: maskCI)
        }
    }

    func beginBrushStroke() {
        activeBrush = activeBrush ?? BrushMask()
        currentStroke = BrushStroke(
            radius: brushSettings.radius,
            hardness: brushSettings.hardness,
            opacity: brushSettings.opacity,
            isErasing: brushSettings.isErasing
        )
    }

    func addBrushPoint(_ point: CGPoint) {
        currentStroke?.points.append(point)
    }

    func endBrushStroke() async {
        guard let stroke = currentStroke, let image = baseImage else { return }
        await activeBrush?.addStroke(stroke)
        currentStroke = nil
        if let maskCI = try? await activeBrush?.generateMask(for: image) {
            await renderPreview(mask: maskCI)
        }
    }

    func removeMaskLayer(id: UUID) {
        maskLayers.removeAll { $0.id == id }
    }

    func toggleMaskVisibility(id: UUID) {
        if let idx = maskLayers.firstIndex(where: { $0.id == id }) {
            maskLayers[idx].isVisible.toggle()
        }
    }

    func invertMask(id: UUID) {
        if let idx = maskLayers.firstIndex(where: { $0.id == id }) {
            maskLayers[idx].invertMask.toggle()
        }
    }

    private func renderPreview(mask: CIImage) async {
        let preview = await Task.detached(priority: .userInitiated) { [context, mask] () -> UIImage? in
            guard let cg = context.createCGImage(mask, from: mask.extent) else { return nil }
            return UIImage(cgImage: cg)
        }.value
        maskPreviewImage = preview
    }

    private func toPNG(_ image: CIImage) -> Data? {
        guard let cg = context.createCGImage(image, from: image.extent) else { return nil }
        return UIImage(cgImage: cg).pngData()
    }
}
