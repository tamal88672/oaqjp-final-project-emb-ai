import Foundation
import CoreImage
import Vision

actor AutoEditEngine {
    static let shared = AutoEditEngine()

    private let exposureAdjuster    = ExposureAdjuster()
    private let whiteBalance        = WhiteBalanceAdjuster()
    private let saturationAdjuster  = SaturationAdjuster()
    private let sharpnessAdjuster   = SharpnessAdjuster()
    private let noiseReducer        = NoiseReducer()

    private let context: CIContext = {
        if let device = MTLCreateSystemDefaultDevice() {
            return CIContext(mtlDevice: device, options: [
                .useSoftwareRenderer: false,
                .workingColorSpace: CGColorSpace(name: CGColorSpace.displayP3) as Any
            ])
        }
        return CIContext()
    }()

    /// Returns the processed CIImage or nil if loading failed.
    func process(photo: CapturedPhoto, preset: AutoEditPreset) async -> CIImage? {
        guard let base = loadCIImage(from: photo) else { return nil }

        // 1. Auto-adjust (Apple's built-in pipeline)
        let autoAdjusted = applyAutoAdjust(base)

        // 2. Detect faces for smart preset application
        let faces = await detectFaces(in: autoAdjusted)

        // 3. Apply preset + per-parameter adjustments
        let editState = preset == .none
            ? EditState.identity
            : adjustedState(preset.baselineEdit, faces: faces)

        return applyEditState(editState, to: autoAdjusted)
    }

    func applyEditState(_ state: EditState, to image: CIImage) -> CIImage {
        var result = image

        result = exposureAdjuster.adjust(
            image: result,
            ev: state.exposure,
            highlights: state.highlights,
            shadows: state.shadows,
            whites: state.whites,
            blacks: state.blacks
        )
        result = whiteBalance.adjust(image: result, temperature: state.temperature, tint: state.tint)
        result = saturationAdjuster.adjust(image: result, saturation: state.saturation, vibrance: state.vibrance)
        result = sharpnessAdjuster.adjust(image: result, sharpness: state.sharpness, clarity: state.clarity)
        result = noiseReducer.reduce(image: result, amount: state.noiseReduction)

        return result
    }

    // MARK: - Private

    private func loadCIImage(from photo: CapturedPhoto) -> CIImage? {
        if photo.format.isRAW {
            let tmpURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(photo.filename)
            try? photo.rawData.write(to: tmpURL)
            if #available(iOS 15, *) {
                return CIRAWFilter.filter(imageURL: tmpURL)?.outputImage
            }
            return CIImage(contentsOf: tmpURL)
        }
        return CIImage(data: photo.rawData)
    }

    private func applyAutoAdjust(_ image: CIImage) -> CIImage {
        let options: [CIImageAutoAdjustmentOption: Any] = [
            .enhance: true,
            .redEye: true
        ]
        let filters = image.autoAdjustmentFilters(options: options)
        return filters.reduce(image) { img, filter in
            filter.setValue(img, forKey: kCIInputImageKey)
            return filter.outputImage ?? img
        }
    }

    private func detectFaces(in image: CIImage) async -> [VNFaceObservation] {
        return await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNDetectFaceRectanglesRequest()
                let handler = VNImageRequestHandler(ciImage: image, options: [:])
                try? handler.perform([request])
                cont.resume(returning: (request.results ?? []))
            }
        }
    }

    private func adjustedState(_ base: EditState, faces: [VNFaceObservation]) -> EditState {
        var s = base
        // If faces detected with portrait preset, boost skin-friendly settings
        if !faces.isEmpty && base.preset == .portrait {
            s.noiseReduction = max(s.noiseReduction, 0.3)
        }
        return s
    }
}
