import Foundation
import CoreImage
import Vision

actor SkyDetectionMask: MaskGenerator {

    func generateMask(for image: CIImage) async throws -> CIImage {
        if #available(iOS 17, *) {
            if let mask = try? await foregroundInstanceMask(for: image) {
                return mask
            }
        }
        return heuristicSkyMask(for: image)
    }

    @available(iOS 17, *)
    private func foregroundInstanceMask(for image: CIImage) async throws -> CIImage {
        return try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNGenerateForegroundInstanceMaskRequest()
                let handler = VNImageRequestHandler(ciImage: image, options: [:])
                do {
                    try handler.perform([request])
                    if let obs = request.results?.first,
                       let pixelBuffer = try? obs.generateMaskedImage(ofInstances: obs.allInstances,
                                                                        from: handler,
                                                                        croppedToInstancesExtent: false) {
                        // Invert foreground mask to get sky
                        var fgMask = CIImage(cvPixelBuffer: pixelBuffer)
                        fgMask = MaskCompositor.scaleMask(fgMask, to: image)
                        let inverted = CIFilter(name: "CIColorInvert", parameters: [kCIInputImageKey: fgMask])?.outputImage ?? fgMask
                        cont.resume(returning: inverted)
                    } else {
                        cont.resume(throwing: NSError(domain: "Sky", code: 0))
                    }
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }

    private func heuristicSkyMask(for image: CIImage) -> CIImage {
        // Extract blue/cyan pixels with high luminosity in upper image region
        guard let colorKernel = makeColorKernel() else { return solidBlack(for: image) }
        let skyColor = colorKernel.apply(extent: image.extent, arguments: [image]) ?? solidBlack(for: image)

        // Gradient: full mask at top, fade to zero at 40% height
        let gradient = CIFilter(name: "CILinearGradient", parameters: [
            "inputPoint0": CIVector(x: 0, y: image.extent.maxY),
            "inputPoint1": CIVector(x: 0, y: image.extent.maxY * 0.6),
            "inputColor0": CIColor.white,
            "inputColor1": CIColor.black
        ])?.outputImage?.cropped(to: image.extent) ?? solidBlack(for: image)

        return CIFilter(name: "CIMultiplyCompositing", parameters: [
            kCIInputImageKey: skyColor,
            kCIInputBackgroundImageKey: gradient
        ])?.outputImage?.cropped(to: image.extent) ?? skyColor
    }

    private func makeColorKernel() -> CIColorKernel? {
        // Selects blue/grey sky pixels: hue 180°–260°, luminosity > 0.35
        let src = """
        kernel vec4 skyDetect(__sample s) {
            float r = s.r, g = s.g, b = s.b;
            float maxC = max(r, max(g, b));
            float minC = min(r, min(g, b));
            float delta = maxC - minC;
            float lum = 0.2126 * r + 0.7152 * g + 0.0722 * b;
            float hue = 0.0;
            if (delta > 0.001) {
                if (maxC == b) hue = (r - g) / delta + 4.0;
                else if (maxC == g) hue = (b - r) / delta + 2.0;
                else hue = mod((g - b) / delta, 6.0);
                hue = hue / 6.0;
            }
            float isSky = (hue > 0.5 && hue < 0.72 && lum > 0.35) ? 1.0 : 0.0;
            return vec4(isSky, isSky, isSky, 1.0);
        }
        """
        return CIColorKernel(source: src)
    }

    private func solidBlack(for image: CIImage) -> CIImage {
        CIImage(color: .black).cropped(to: image.extent)
    }
}
