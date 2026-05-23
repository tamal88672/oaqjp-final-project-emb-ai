import CoreImage
import CoreImage.CIFilterBuiltins

enum DodgeBurnType { case dodge, burn }

enum TonalRange {
    case shadows, midtones, highlights

    func luminosityRange() -> (low: Float, high: Float) {
        switch self {
        case .shadows:    return (0, 0.33)
        case .midtones:   return (0.25, 0.75)
        case .highlights: return (0.67, 1.0)
        }
    }
}

struct DodgeBurnFilter {
    func apply(
        to image: CIImage,
        type: DodgeBurnType,
        strength: Float,
        range: TonalRange,
        brushMask: CIImage
    ) -> CIImage {
        let (lo, hi) = range.luminosityRange()
        let lumMask  = buildLumMask(image: image, low: lo, high: hi)

        // Combine brush mask × luminosity mask
        let combinedMask = CIFilter(name: "CIMultiplyCompositing", parameters: [
            kCIInputImageKey: brushMask,
            kCIInputBackgroundImageKey: lumMask
        ])?.outputImage ?? brushMask

        switch type {
        case .dodge:
            let ev = strength * 1.5
            let adjusted = CIFilter.exposureAdjust()
            adjusted.inputImage = image
            adjusted.ev = ev
            let dodged = adjusted.outputImage ?? image
            return MaskCompositor.apply(mask: combinedMask, edited: dodged, original: image, feather: 0)

        case .burn:
            let ev = -strength * 1.5
            let adjusted = CIFilter.exposureAdjust()
            adjusted.inputImage = image
            adjusted.ev = ev
            let burned = adjusted.outputImage ?? image
            return MaskCompositor.apply(mask: combinedMask, edited: burned, original: image, feather: 0)
        }
    }

    private func buildLumMask(image: CIImage, low: Float, high: Float) -> CIImage {
        guard let kernel = CIColorKernel(source: """
            kernel vec4 lum(__sample s, float lo, float hi) {
                float l = 0.2126*s.r + 0.7152*s.g + 0.0722*s.b;
                float v = smoothstep(lo, lo+0.05, l) * (1.0 - smoothstep(hi-0.05, hi, l));
                return vec4(v, v, v, 1.0);
            }
        """) else {
            return CIImage(color: .white).cropped(to: image.extent)
        }
        return kernel.apply(extent: image.extent, arguments: [image, CGFloat(low), CGFloat(high)])
            ?? CIImage(color: .white).cropped(to: image.extent)
    }
}
