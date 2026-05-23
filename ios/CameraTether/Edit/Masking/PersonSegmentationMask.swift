import Foundation
import CoreImage
import Vision

actor PersonSegmentationMask: MaskGenerator {
    var quality: VNGeneratePersonSegmentationRequest.QualityLevel = .accurate

    func generateMask(for image: CIImage) async throws -> CIImage {
        let pixelBuffer = try await runSegmentation(image: image)
        var mask = CIImage(cvPixelBuffer: pixelBuffer)
        mask = MaskCompositor.scaleMask(mask, to: image)
        return mask
    }

    private func runSegmentation(image: CIImage) async throws -> CVPixelBuffer {
        return try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNGeneratePersonSegmentationRequest()
                request.qualityLevel = self.quality
                request.outputPixelFormat = kCVPixelFormatType_OneComponent8
                let handler = VNImageRequestHandler(ciImage: image, options: [:])
                do {
                    try handler.perform([request])
                    if let obs = request.results?.first {
                        cont.resume(returning: obs.pixelBuffer)
                    } else {
                        cont.resume(throwing: NSError(domain: "Mask", code: 0,
                            userInfo: [NSLocalizedDescriptionKey: "No person detected"]))
                    }
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }
}
