import CoreImage
import CoreImage.CIFilterBuiltins
import Vision

struct SkinSmoothingFilter {
    /// amount: 0..1; faceRects in image coordinate space (origin bottom-left)
    func apply(to image: CIImage, amount: Float, faceRects: [CGRect]) -> CIImage {
        guard amount > 0 else { return image }

        // Frequency separation: low = blurred color; high = detail layer
        let blurFilter = CIFilter.gaussianBlur()
        blurFilter.inputImage = image
        blurFilter.radius = 6
        guard let lowFreq = blurFilter.outputImage else { return image }

        // Blend original and low-freq to smooth amount
        guard let blended = CIFilter(name: "CIBlendWithAlphaMask", parameters: [
            kCIInputImageKey: lowFreq,
            kCIInputBackgroundImageKey: image,
            kCIInputMaskImageKey: CIImage(color: CIColor(red: CGFloat(amount), green: CGFloat(amount), blue: CGFloat(amount))).cropped(to: image.extent)
        ])?.outputImage else { return image }

        // Apply only to face/skin regions
        if faceRects.isEmpty { return blended }

        // Build a mask covering face rectangles
        let maskImage = buildFaceMask(faceRects: faceRects, extent: image.extent)
        return MaskCompositor.apply(mask: maskImage, edited: blended, original: image, feather: 10)
    }

    private func buildFaceMask(faceRects: [CGRect], extent: CGRect) -> CIImage {
        var mask = CIImage(color: .black).cropped(to: extent)
        for rect in faceRects {
            let faceWhite = CIImage(color: .white).cropped(to: rect)
            mask = CIFilter(name: "CISourceOverCompositing", parameters: [
                kCIInputImageKey: faceWhite,
                kCIInputBackgroundImageKey: mask
            ])?.outputImage ?? mask
        }
        // Feather mask edges
        let blur = CIFilter.gaussianBlur()
        blur.inputImage = mask
        blur.radius = 20
        return blur.outputImage?.cropped(to: extent) ?? mask
    }
}
