import Foundation
import CoreImage

actor ColorRangeMask: MaskGenerator {
    var targetHue: Float       // 0..1 normalized hue
    var hueTolerance: Float    // 0..0.5
    var saturationMin: Float = 0.1
    var luminosityRange: ClosedRange<Float> = 0...1

    init(targetHue: Float, hueTolerance: Float = 0.1) {
        self.targetHue = targetHue
        self.hueTolerance = hueTolerance
    }

    func generateMask(for image: CIImage) async throws -> CIImage {
        guard let kernel = makeKernel() else {
            return CIImage(color: .black).cropped(to: image.extent)
        }
        let h  = CGFloat(targetHue)
        let tol = CGFloat(hueTolerance)
        let lMin = CGFloat(luminosityRange.lowerBound)
        let lMax = CGFloat(luminosityRange.upperBound)
        let sMin = CGFloat(saturationMin)
        guard let result = kernel.apply(
            extent: image.extent,
            arguments: [image, h, tol, lMin, lMax, sMin]
        ) else {
            return CIImage(color: .black).cropped(to: image.extent)
        }
        return result
    }

    private func makeKernel() -> CIColorKernel? {
        let src = """
        kernel vec4 colorRange(__sample s, float targetHue, float tol,
                               float lMin, float lMax, float sMin) {
            float r = s.r, g = s.g, b = s.b;
            float maxC = max(r, max(g, b));
            float minC = min(r, min(g, b));
            float delta = maxC - minC;
            float lum = 0.2126 * r + 0.7152 * g + 0.0722 * b;
            float sat = (maxC > 0.0) ? delta / maxC : 0.0;
            float hue = 0.0;
            if (delta > 0.001) {
                if (maxC == r) hue = mod((g - b) / delta, 6.0);
                else if (maxC == g) hue = (b - r) / delta + 2.0;
                else hue = (r - g) / delta + 4.0;
                hue = hue / 6.0;
            }
            float hueDist = abs(hue - targetHue);
            if (hueDist > 0.5) hueDist = 1.0 - hueDist;
            float match = smoothstep(tol, 0.0, hueDist);
            match *= (sat >= sMin && lum >= lMin && lum <= lMax) ? 1.0 : 0.0;
            return vec4(match, match, match, 1.0);
        }
        """
        return CIColorKernel(source: src)
    }
}
