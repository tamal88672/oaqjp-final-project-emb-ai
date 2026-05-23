import CoreImage
import CoreImage.CIFilterBuiltins

struct ExposureAdjuster {
    /// exposure: EV in -2..+2; highlights/shadows/whites/blacks: -100..+100
    func adjust(
        image: CIImage,
        ev: Float,
        highlights: Float,
        shadows: Float,
        whites: Float,
        blacks: Float
    ) -> CIImage {
        // 1. Exposure adjustment
        var result = image
        if ev != 0 {
            let expFilter = CIFilter.exposureAdjust()
            expFilter.inputImage = result
            expFilter.ev = ev
            result = expFilter.outputImage ?? result
        }

        // 2. Tone curve for highlights / shadows / whites / blacks
        let needsTone = highlights != 0 || shadows != 0 || whites != 0 || blacks != 0
        if needsTone {
            let h  = clamp01(0.75 + Float(highlights) / 400)
            let s  = clamp01(0.25 + Float(shadows)    / 400)
            let w  = clamp01(1.00 + Float(whites)      / 400)
            let b  = clamp01(0.00 + Float(blacks)      / 400)

            if let tone = CIFilter(name: "CIToneCurve") {
                tone.setValue(result, forKey: kCIInputImageKey)
                tone.setValue(CIVector(x: 0.0, y: CGFloat(b)),  forKey: "inputPoint0")
                tone.setValue(CIVector(x: 0.25, y: CGFloat(s)), forKey: "inputPoint1")
                tone.setValue(CIVector(x: 0.5,  y: 0.5),        forKey: "inputPoint2")
                tone.setValue(CIVector(x: 0.75, y: CGFloat(h)), forKey: "inputPoint3")
                tone.setValue(CIVector(x: 1.0,  y: CGFloat(w)), forKey: "inputPoint4")
                result = tone.outputImage ?? result
            }
        }
        return result
    }

    private func clamp01(_ v: Float) -> Float { max(0, min(1, v)) }
}
