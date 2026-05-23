import Foundation
import CoreImage

actor LuminosityMask: MaskGenerator {
    var lowPoint: Float    // 0..1
    var highPoint: Float   // 0..1
    var smoothing: Float   // 0..1 (controls falloff width)

    init(low: Float = 0, high: Float = 1, smoothing: Float = 0.1) {
        self.lowPoint  = low
        self.highPoint = high
        self.smoothing = smoothing
    }

    func generateMask(for image: CIImage) async throws -> CIImage {
        guard let kernel = makeKernel() else {
            return CIImage(color: .white).cropped(to: image.extent)
        }
        let lo = CGFloat(lowPoint)
        let hi = CGFloat(highPoint)
        let sm = CGFloat(smoothing)
        return kernel.apply(extent: image.extent, arguments: [image, lo, hi, sm])
            ?? CIImage(color: .white).cropped(to: image.extent)
    }

    private func makeKernel() -> CIColorKernel? {
        let src = """
        kernel vec4 lumMask(__sample s, float lo, float hi, float smooth) {
            float lum = 0.2126 * s.r + 0.7152 * s.g + 0.0722 * s.b;
            float halfW = max(smooth * 0.5, 0.001);
            float v = smoothstep(lo - halfW, lo + halfW, lum)
                    * (1.0 - smoothstep(hi - halfW, hi + halfW, lum));
            return vec4(v, v, v, 1.0);
        }
        """
        return CIColorKernel(source: src)
    }
}
