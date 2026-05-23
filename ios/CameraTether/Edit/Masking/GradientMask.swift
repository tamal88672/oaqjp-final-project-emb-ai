import Foundation
import CoreImage

actor GradientMask: MaskGenerator {
    var startPoint: CGPoint   // unit coords 0..1
    var endPoint: CGPoint     // unit coords 0..1
    var isRadial: Bool

    init(startPoint: CGPoint, endPoint: CGPoint, isRadial: Bool = false) {
        self.startPoint = startPoint
        self.endPoint   = endPoint
        self.isRadial   = isRadial
    }

    func generateMask(for image: CIImage) async throws -> CIImage {
        let extent = image.extent
        let sp = CGPoint(x: startPoint.x * extent.width,  y: startPoint.y * extent.height)
        let ep = CGPoint(x: endPoint.x   * extent.width,  y: endPoint.y   * extent.height)

        if isRadial {
            let radius = hypot(ep.x - sp.x, ep.y - sp.y)
            return CIFilter(name: "CIRadialGradient", parameters: [
                "inputCenter":  CIVector(x: sp.x, y: sp.y),
                "inputRadius0": 0,
                "inputRadius1": radius,
                "inputColor0":  CIColor.white,
                "inputColor1":  CIColor.black
            ])?.outputImage?.cropped(to: extent) ?? CIImage(color: .white).cropped(to: extent)
        } else {
            return CIFilter(name: "CILinearGradient", parameters: [
                "inputPoint0": CIVector(x: sp.x, y: sp.y),
                "inputPoint1": CIVector(x: ep.x, y: ep.y),
                "inputColor0": CIColor.white,
                "inputColor1": CIColor.black
            ])?.outputImage?.cropped(to: extent) ?? CIImage(color: .white).cropped(to: extent)
        }
    }
}
