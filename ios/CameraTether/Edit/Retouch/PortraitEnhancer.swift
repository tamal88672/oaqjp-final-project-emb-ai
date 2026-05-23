import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import Vision

actor PortraitEnhancer {
    func enhance(
        image: CIImage,
        eyeEnhancement: Float,
        teethWhitening: Float,
        skinToneShift: Float
    ) async -> CIImage {
        let observations = await detectLandmarks(in: image)
        var result = image

        for obs in observations {
            let boundingBox = VNImageRectForNormalizedRect(obs.boundingBox,
                                                           Int(image.extent.width),
                                                           Int(image.extent.height))
            if eyeEnhancement > 0 {
                result = applyEyeEnhancement(image: result, observation: obs,
                                             boundingBox: boundingBox, amount: eyeEnhancement)
            }
            if teethWhitening > 0 {
                result = applyTeethWhitening(image: result, observation: obs,
                                              boundingBox: boundingBox, amount: teethWhitening)
            }
        }
        return result
    }

    private func detectLandmarks(in image: CIImage) async -> [VNFaceObservation] {
        return await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let req = VNDetectFaceLandmarksRequest()
                let handler = VNImageRequestHandler(ciImage: image, options: [:])
                try? handler.perform([req])
                cont.resume(returning: req.results ?? [])
            }
        }
    }

    private func applyEyeEnhancement(
        image: CIImage,
        observation: VNFaceObservation,
        boundingBox: CGRect,
        amount: Float
    ) -> CIImage {
        guard let landmarks = observation.landmarks else { return image }
        var result = image
        for region in [landmarks.leftEye, landmarks.rightEye].compactMap({ $0 }) {
            let eyeRect = normalizedRegionRect(region: region, face: boundingBox, image: image.extent)
            let sharpened = CIFilter.unsharpMask()
            sharpened.inputImage = result.cropped(to: eyeRect)
            sharpened.radius = 1.5
            sharpened.intensity = amount * 0.8
            if let eyeOutput = sharpened.outputImage {
                result = CIFilter(name: "CISourceOverCompositing", parameters: [
                    kCIInputImageKey: eyeOutput,
                    kCIInputBackgroundImageKey: result
                ])?.outputImage ?? result
            }
        }
        return result
    }

    private func applyTeethWhitening(
        image: CIImage,
        observation: VNFaceObservation,
        boundingBox: CGRect,
        amount: Float
    ) -> CIImage {
        guard let innerLips = observation.landmarks?.innerLips else { return image }
        let mouthRect = normalizedRegionRect(region: innerLips, face: boundingBox, image: image.extent)
            .insetBy(dx: 0, dy: -mouthRect(boundingBox).height * 0.1)

        let region = image.cropped(to: mouthRect)
        let desat = CIFilter.colorControls()
        desat.inputImage = region
        desat.saturation = 0.7 - amount * 0.3
        desat.brightness = amount * 0.05

        if let whitened = desat.outputImage {
            return CIFilter(name: "CISourceOverCompositing", parameters: [
                kCIInputImageKey: whitened,
                kCIInputBackgroundImageKey: image
            ])?.outputImage ?? image
        }
        return image
    }

    private func normalizedRegionRect(
        region: VNFaceLandmarkRegion2D,
        face: CGRect,
        image: CGRect
    ) -> CGRect {
        let pts = region.normalizedPoints
        guard !pts.isEmpty else { return .zero }
        let xs = pts.map { $0.x * face.width + face.minX }
        let ys = pts.map { $0.y * face.height + face.minY }
        let minX = xs.min()!, maxX = xs.max()!
        let minY = ys.min()!, maxY = ys.max()!
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            .insetBy(dx: -5, dy: -5)
            .intersection(image)
    }

    private func mouthRect(_ face: CGRect) -> CGRect { face }
}
