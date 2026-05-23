import CoreImage

struct SpotHealingFilter {
    /// Heals a circular region by sampling a nearby patch.
    func heal(image: CIImage, center: CGPoint, radius: Float) -> CIImage {
        let r = CGFloat(radius)
        let destRect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)

        // Sample source patch offset to the right by 2.5× radius
        let srcOffset = CGPoint(x: center.x + r * 2.5, y: center.y)
        let srcRect   = CGRect(x: srcOffset.x - r, y: srcOffset.y - r, width: r * 2, height: r * 2)
        let srcPatch  = image.cropped(to: srcRect)
            .transformed(by: CGAffineTransform(translationX: destRect.minX - srcRect.minX,
                                               y: destRect.minY - srcRect.minY))

        // Create circular alpha mask
        let circleMask = CIFilter(name: "CIRadialGradient", parameters: [
            "inputCenter":  CIVector(x: center.x, y: center.y),
            "inputRadius0": r * 0.7,
            "inputRadius1": r,
            "inputColor0":  CIColor.white,
            "inputColor1":  CIColor.black
        ])?.outputImage?.cropped(to: image.extent)

        // Blend source patch into image at destination
        guard let maskImage = circleMask else { return image }
        let healed = CIFilter(name: "CIBlendWithMask", parameters: [
            kCIInputImageKey:     srcPatch,
            kCIInputBackgroundImageKey: image,
            kCIInputMaskImageKey: maskImage
        ])?.outputImage ?? image

        // Blur at seam edge
        let blurFilter = CIFilter.gaussianBlur()
        blurFilter.inputImage = healed.cropped(to: destRect.insetBy(dx: -r * 0.3, dy: -r * 0.3))
        blurFilter.radius = Float(r * 0.15)
        guard let seamBlurred = blurFilter.outputImage else { return healed }

        return CIFilter(name: "CISourceOverCompositing", parameters: [
            kCIInputImageKey:           healed,
            kCIInputBackgroundImageKey: seamBlurred
        ])?.outputImage ?? healed
    }
}
