import CoreImage

struct CloneStampFilter {
    var sourcePoint: CGPoint
    var destinationPoint: CGPoint
    var radius: Float
    var opacity: Float

    func apply(to image: CIImage) -> CIImage {
        let r = CGFloat(radius)
        let srcRect = CGRect(x: sourcePoint.x - r, y: sourcePoint.y - r, width: r * 2, height: r * 2)
        let dstRect = CGRect(x: destinationPoint.x - r, y: destinationPoint.y - r, width: r * 2, height: r * 2)

        // Crop source patch and translate to destination
        let dx = destinationPoint.x - sourcePoint.x
        let dy = destinationPoint.y - sourcePoint.y
        let sourcePatch = image.cropped(to: srcRect)
            .transformed(by: CGAffineTransform(translationX: dx, y: dy))

        // Circular soft mask at destination
        guard let mask = CIFilter(name: "CIRadialGradient", parameters: [
            "inputCenter":  CIVector(x: destinationPoint.x, y: destinationPoint.y),
            "inputRadius0": r * 0.6,
            "inputRadius1": r,
            "inputColor0":  CIColor(red: CGFloat(opacity), green: CGFloat(opacity), blue: CGFloat(opacity)),
            "inputColor1":  CIColor.black
        ])?.outputImage?.cropped(to: image.extent) else { return image }

        return CIFilter(name: "CIBlendWithMask", parameters: [
            kCIInputImageKey:     sourcePatch,
            kCIInputBackgroundImageKey: image,
            kCIInputMaskImageKey: mask
        ])?.outputImage ?? image
    }
}
