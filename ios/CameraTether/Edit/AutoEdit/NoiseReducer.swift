import CoreImage
import CoreImage.CIFilterBuiltins

struct NoiseReducer {
    /// amount: 0..1
    func reduce(image: CIImage, amount: Float) -> CIImage {
        guard amount > 0 else { return image }
        let capped = min(amount, 0.8)
        let f = CIFilter.noiseReduction()
        f.inputImage = image
        f.noiseLevel = capped * 0.02
        f.sharpness  = Float(0.4 + Double(1 - capped) * 0.4)
        return f.outputImage ?? image
    }
}
