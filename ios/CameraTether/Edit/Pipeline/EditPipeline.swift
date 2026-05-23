import Foundation
import CoreImage
import CoreGraphics

actor EditPipeline {
    private var baseImage: CIImage?
    private var operations: [EditOperation] = []
    private let engine = AutoEditEngine.shared

    private let context: CIContext = {
        if let device = MTLCreateSystemDefaultDevice() {
            return CIContext(mtlDevice: device, options: [
                .useSoftwareRenderer: false,
                .workingColorSpace: CGColorSpace(name: CGColorSpace.displayP3) as Any
            ])
        }
        return CIContext()
    }()

    func setBase(_ image: CIImage) {
        baseImage = image
        operations = []
    }

    func apply(_ operation: EditOperation) -> CIImage? {
        operations.removeAll { $0.id == operation.id }
        operations.append(operation)
        return renderCurrent()
    }

    func remove(operationID: UUID) -> CIImage? {
        operations.removeAll { $0.id == operationID }
        return renderCurrent()
    }

    func reorder(from: Int, to: Int) -> CIImage? {
        guard from != to,
              operations.indices.contains(from),
              operations.indices.contains(to) else { return renderCurrent() }
        let op = operations.remove(at: from)
        operations.insert(op, at: to)
        return renderCurrent()
    }

    func renderPreview(maxDimension: CGFloat) -> CIImage? {
        guard let base = baseImage else { return nil }
        let scale = min(maxDimension / base.extent.width, maxDimension / base.extent.height, 1)
        let scaled = base.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let temp = actor_setBase(scaled)
        let preview = renderCurrent()
        baseImage = base
        operations = temp
        return preview
    }

    func render() -> CGImage? {
        guard let result = renderCurrent() else { return nil }
        return context.createCGImage(result, from: result.extent)
    }

    // MARK: - Private

    private func renderCurrent() -> CIImage? {
        guard let base = baseImage else { return nil }
        var result = base
        for op in operations where op.isEnabled {
            result = engine.applyEditState(op.parameters, to: result)
        }
        return result
    }

    private func actor_setBase(_ image: CIImage) -> [EditOperation] {
        let saved = operations
        baseImage = image
        operations = []
        return saved
    }
}
