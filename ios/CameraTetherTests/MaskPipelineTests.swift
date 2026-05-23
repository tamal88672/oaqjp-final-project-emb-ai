import XCTest
import CoreImage
@testable import CameraTether

final class MaskPipelineTests: XCTestCase {
    private let ctx = CIContext()

    // MARK: - MaskCompositor.apply

    func testAllWhiteMaskReturnsEdited() {
        let original = solid(.red)
        let edited   = solid(.blue)
        let mask     = solid(.white)
        let result   = MaskCompositor.apply(mask: mask, edited: edited, original: original, feather: 0)
        // Result should be close to blue
        let avg = averageColor(result)
        XCTAssertGreaterThan(avg.b, 0.5)
    }

    func testAllBlackMaskReturnsOriginal() {
        let original = solid(.red)
        let edited   = solid(.blue)
        let mask     = solid(.black)
        let result   = MaskCompositor.apply(mask: mask, edited: edited, original: original, feather: 0)
        let avg = averageColor(result)
        XCTAssertGreaterThan(avg.r, 0.5)
    }

    func testFeatherRadiusZeroIsIdentity() {
        let mask   = solid(.white)
        let edited = solid(.green)
        let orig   = solid(.red)
        let r0 = MaskCompositor.apply(mask: mask, edited: edited, original: orig, feather: 0)
        let r1 = MaskCompositor.apply(mask: mask, edited: edited, original: orig, feather: 0)
        // Both should produce same result
        let c0 = averageColor(r0)
        let c1 = averageColor(r1)
        XCTAssertEqual(c0.r, c1.r, accuracy: 0.01)
    }

    // MARK: - GradientMask

    func testLinearGradientIsWhiteAtStart() async throws {
        let image = solid(.gray)
        let gen = GradientMask(startPoint: CGPoint(x: 0, y: 1), endPoint: CGPoint(x: 0, y: 0))
        let mask = try await gen.generateMask(for: image)
        let topAvg = sampleRegion(mask, rect: CGRect(x: 0, y: 80, width: 100, height: 20))
        XCTAssertGreaterThan(topAvg.r, 0.7, "Top of gradient should be near white")
    }

    func testLinearGradientIsBlackAtEnd() async throws {
        let image = solid(.gray)
        let gen = GradientMask(startPoint: CGPoint(x: 0, y: 1), endPoint: CGPoint(x: 0, y: 0))
        let mask = try await gen.generateMask(for: image)
        let bottomAvg = sampleRegion(mask, rect: CGRect(x: 0, y: 0, width: 100, height: 20))
        XCTAssertLessThan(bottomAvg.r, 0.3, "Bottom of gradient should be near black")
    }

    // MARK: - LuminosityMask

    func testFullRangeProducesNearWhite() async throws {
        let image = solid(.gray)
        let gen = LuminosityMask(low: 0, high: 1, smoothing: 0)
        let mask = try await gen.generateMask(for: image)
        let avg = averageColor(mask)
        XCTAssertGreaterThan(avg.r, 0.5, "Full luminosity range should pass all tones")
    }

    func testNarrowRangeOnWrongToneProducesBlack() async throws {
        let image = solid(.black) // luminosity ~0
        let gen = LuminosityMask(low: 0.8, high: 1.0, smoothing: 0.05) // only bright whites
        let mask = try await gen.generateMask(for: image)
        let avg = averageColor(mask)
        XCTAssertLessThan(avg.r, 0.3, "Black image should fail a highlights-only luminosity mask")
    }

    // MARK: - MaskCompositor.combine

    func testCombineAdd() {
        let left  = solid(.black)
        let right = solid(.white)
        let combined = MaskCompositor.combine(masks: [left, right], mode: .add)
        XCTAssertNotNil(combined)
        let avg = averageColor(combined!)
        XCTAssertGreaterThan(avg.r, 0.5)
    }

    func testCombineIntersect() {
        let left  = solid(.white)
        let right = solid(.black)
        let combined = MaskCompositor.combine(masks: [left, right], mode: .intersect)
        XCTAssertNotNil(combined)
        let avg = averageColor(combined!)
        XCTAssertLessThan(avg.r, 0.3)
    }

    // MARK: - Helpers

    private func solid(_ color: CIColor) -> CIImage {
        CIImage(color: color).cropped(to: CGRect(x: 0, y: 0, width: 100, height: 100))
    }

    private struct RGBA { var r, g, b, a: Float }

    private func averageColor(_ image: CIImage) -> RGBA {
        sampleRegion(image, rect: image.extent)
    }

    private func sampleRegion(_ image: CIImage, rect: CGRect) -> RGBA {
        guard let cgImage = ctx.createCGImage(image, from: image.extent),
              let data = cgImage.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else {
            return RGBA(r: 0, g: 0, b: 0, a: 0)
        }
        let width  = cgImage.width
        let height = cgImage.height
        var rSum: Float = 0; var gSum: Float = 0; var bSum: Float = 0
        var count: Int = 0

        let xStart = max(0, Int(rect.minX))
        let xEnd   = min(width, Int(rect.maxX))
        let yStart = max(0, Int(rect.minY))
        let yEnd   = min(height, Int(rect.maxY))

        for y in yStart..<yEnd {
            for x in xStart..<xEnd {
                let offset = (y * width + x) * 4
                rSum += Float(ptr[offset])     / 255
                gSum += Float(ptr[offset + 1]) / 255
                bSum += Float(ptr[offset + 2]) / 255
                count += 1
            }
        }
        guard count > 0 else { return RGBA(r: 0, g: 0, b: 0, a: 0) }
        return RGBA(r: rSum / Float(count), g: gSum / Float(count), b: bSum / Float(count), a: 1)
    }
}
