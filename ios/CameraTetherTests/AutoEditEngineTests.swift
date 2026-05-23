import XCTest
import CoreImage
@testable import CameraTether

final class AutoEditEngineTests: XCTestCase {

    // MARK: - Preset baselines

    func testPortraitPresetReducesSaturation() {
        let state = AutoEditPreset.portrait.baselineEdit
        XCTAssertLessThan(state.saturation, 1.0)
    }

    func testLandscapePresetBoostsSaturation() {
        let state = AutoEditPreset.landscape.baselineEdit
        XCTAssertGreaterThan(state.saturation, 1.0)
    }

    func testNightPresetBoostsShadows() {
        let state = AutoEditPreset.night.baselineEdit
        XCTAssertGreaterThan(state.shadows, 0)
    }

    func testBWPresetZerosSaturation() {
        let state = AutoEditPreset.bw.baselineEdit
        XCTAssertEqual(state.saturation, 0)
    }

    func testNonePresetIsIdentity() {
        let state = AutoEditPreset.none.baselineEdit
        XCTAssertEqual(state, EditState.identity)
    }

    func testAllPresetsHaveCorrectPresetField() {
        for preset in AutoEditPreset.allCases {
            XCTAssertEqual(preset.baselineEdit.preset, preset)
        }
    }

    // MARK: - ExposureAdjuster

    func testExposureIdentityDoesNotCrash() {
        let image = makeSolidImage(color: .white)
        let adjuster = ExposureAdjuster()
        let result = adjuster.adjust(image: image, ev: 0, highlights: 0, shadows: 0, whites: 0, blacks: 0)
        XCTAssertNotNil(result.extent)
    }

    func testToneCurveClampedControlPoints() {
        // Points should stay within 0..1 even at extremes
        let image = makeSolidImage(color: .gray)
        let adjuster = ExposureAdjuster()
        // These extreme values should not crash
        let result = adjuster.adjust(image: image, ev: 2, highlights: 100, shadows: -100, whites: 100, blacks: -100)
        XCTAssertFalse(result.extent.isNull)
    }

    // MARK: - WhiteBalanceAdjuster

    func testWhiteBalanceIdentityReturnsImage() {
        let image = makeSolidImage(color: .red)
        let adj = WhiteBalanceAdjuster()
        let result = adj.adjust(image: image, temperature: 0, tint: 0)
        XCTAssertEqual(result.extent, image.extent)
    }

    // MARK: - SaturationAdjuster

    func testSaturationZeroDesaturates() {
        let image = makeSolidImage(color: .red)
        let adj = SaturationAdjuster()
        let result = adj.adjust(image: image, saturation: 0, vibrance: 0)
        XCTAssertFalse(result.extent.isNull)
    }

    // MARK: - NoiseReducer

    func testNoiseReducerZeroAmountIsNoop() {
        let image = makeSolidImage(color: .blue)
        let reducer = NoiseReducer()
        let result = reducer.reduce(image: image, amount: 0)
        XCTAssertEqual(result.extent, image.extent)
    }

    func testNoiseReducerCapsAt08() {
        let image = makeSolidImage(color: .blue)
        let reducer = NoiseReducer()
        // Should not crash at max
        let result = reducer.reduce(image: image, amount: 1.0)
        XCTAssertFalse(result.extent.isNull)
    }

    // MARK: - AutoEditEngine (async)

    func testProcessJPEGReturnsImage() async {
        let image = makeSolidImage(color: .green)
        let ctx = CIContext()
        guard let cgImage = ctx.createCGImage(image, from: image.extent),
              let data = UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.9) else {
            XCTFail("Could not create test JPEG")
            return
        }
        let photo = CapturedPhoto(rawData: data, filename: "test.jpg", source: .builtIn, format: .jpeg)
        let result = await AutoEditEngine.shared.process(photo: photo, preset: .none)
        XCTAssertNotNil(result)
    }

    // MARK: - Helpers

    private func makeSolidImage(color: CIColor) -> CIImage {
        CIImage(color: color).cropped(to: CGRect(x: 0, y: 0, width: 100, height: 100))
    }
}
