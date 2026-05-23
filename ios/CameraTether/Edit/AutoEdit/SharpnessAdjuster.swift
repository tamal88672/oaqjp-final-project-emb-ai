import CoreImage
import CoreImage.CIFilterBuiltins

struct SharpnessAdjuster {
    /// sharpness: 0..1; clarity: -100..+100
    func adjust(image: CIImage, sharpness: Float, clarity: Float) -> CIImage {
        var result = image
        if sharpness > 0 {
            let f = CIFilter.unsharpMask()
            f.inputImage = result
            f.radius = Float(1.5 + Double(sharpness) * 1.5)
            f.intensity = sharpness * 0.8
            result = f.outputImage ?? result
        }
        if clarity != 0 {
            // Local contrast: original + clarity_amount * (original - blurred)
            let blurFilter = CIFilter.gaussianBlur()
            blurFilter.inputImage = result
            blurFilter.radius = 20
            if let blurred = blurFilter.outputImage {
                let amount = CGFloat(clarity) / 200.0
                // Blend: result + amount * (result - blurred)
                if let sub = CIFilter(name: "CISubtract") {
                    sub.setValue(result, forKey: "inputImage")
                    sub.setValue(blurred, forKey: "inputBackgroundImage")
                    if let diff = sub.outputImage,
                       let scaled = applyColorMatrix(image: diff, scale: Float(amount)),
                       let added = CIFilter(name: "CIAdd", parameters: [
                           kCIInputImageKey: result,
                           "inputBackgroundImage": scaled
                       ])?.outputImage {
                        result = added
                    }
                }
            }
        }
        return result
    }

    private func applyColorMatrix(image: CIImage, scale: Float) -> CIImage? {
        let f = CIFilter(name: "CIColorMatrix")
        f?.setValue(image, forKey: kCIInputImageKey)
        let v = CIVector(x: CGFloat(scale), y: 0, z: 0, w: 0)
        f?.setValue(v, forKey: "inputRVector")
        f?.setValue(v, forKey: "inputGVector")
        f?.setValue(v, forKey: "inputBVector")
        return f?.outputImage
    }
}
