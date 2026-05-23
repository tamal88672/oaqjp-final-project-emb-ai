import Foundation
import CoreImage

protocol MaskGenerator: Actor {
    /// Returns a grayscale CIImage the same size as `image`.
    /// White (1.0) = apply edits; Black (0.0) = protect original.
    func generateMask(for image: CIImage) async throws -> CIImage
}

struct MaskCompositor {
    enum CombineMode { case add, subtract, intersect }

    static func combine(masks: [CIImage], mode: CombineMode) -> CIImage? {
        guard let first = masks.first else { return nil }
        return masks.dropFirst().reduce(first) { acc, mask in
            switch mode {
            case .add:
                return CIFilter(name: "CIMaximumCompositing", parameters: [
                    kCIInputImageKey: acc,
                    kCIInputBackgroundImageKey: mask
                ])?.outputImage ?? acc
            case .subtract:
                return CIFilter(name: "CIMinimumCompositing", parameters: [
                    kCIInputImageKey: acc,
                    kCIInputBackgroundImageKey: mask
                ])?.outputImage ?? acc
            case .intersect:
                return CIFilter(name: "CIMultiplyCompositing", parameters: [
                    kCIInputImageKey: acc,
                    kCIInputBackgroundImageKey: mask
                ])?.outputImage ?? acc
            }
        }
    }

    /// Blends edited and original using the mask, with optional feathering.
    static func apply(
        mask: CIImage,
        edited: CIImage,
        original: CIImage,
        feather: Float
    ) -> CIImage {
        var finalMask = mask
        if feather > 0 {
            let blur = CIFilter.gaussianBlur()
            blur.inputImage = mask
            blur.radius = feather
            finalMask = blur.outputImage ?? mask
        }
        return CIFilter(name: "CIBlendWithMask", parameters: [
            kCIInputImageKey: edited,
            kCIInputBackgroundImageKey: original,
            kCIInputMaskImageKey: finalMask
        ])?.outputImage ?? original
    }

    /// Scales a mask to match target image dimensions.
    static func scaleMask(_ mask: CIImage, to target: CIImage) -> CIImage {
        let scaleX = target.extent.width  / mask.extent.width
        let scaleY = target.extent.height / mask.extent.height
        return mask.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
    }
}
