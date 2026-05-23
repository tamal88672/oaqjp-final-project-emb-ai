import CoreImage
import CoreImage.CIFilterBuiltins

struct WhiteBalanceAdjuster {
    /// temperature: -100..+100 (negative = cooler, positive = warmer)
    /// tint: -100..+100 (negative = green, positive = magenta)
    func adjust(image: CIImage, temperature: Float, tint: Float) -> CIImage {
        guard temperature != 0 || tint != 0 else { return image }
        guard let filter = CIFilter(name: "CITemperatureAndTint") else { return image }
        // Map -100..+100 to kelvin offset ±1500 around 6500K
        let kelvin = CGFloat(6500 + temperature * 15)
        let tintVal = CGFloat(tint * 1.5)
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
        filter.setValue(CIVector(x: kelvin, y: tintVal), forKey: "inputTargetNeutral")
        return filter.outputImage ?? image
    }
}
