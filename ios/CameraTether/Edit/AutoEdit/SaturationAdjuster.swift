import CoreImage
import CoreImage.CIFilterBuiltins

struct SaturationAdjuster {
    /// saturation: 0..2 (1 = identity)
    /// vibrance: -100..+100
    func adjust(image: CIImage, saturation: Float, vibrance: Float) -> CIImage {
        var result = image
        if saturation != 1.0 {
            let f = CIFilter.colorControls()
            f.inputImage = result
            f.saturation = saturation
            result = f.outputImage ?? result
        }
        if vibrance != 0 {
            if let f = CIFilter(name: "CIVibrance") {
                f.setValue(result, forKey: kCIInputImageKey)
                f.setValue(vibrance / 100.0, forKey: "inputAmount")
                result = f.outputImage ?? result
            }
        }
        return result
    }
}
