import Foundation
import CoreImage
import CoreGraphics

actor BrushMask: MaskGenerator {
    private var strokes: [BrushStroke] = []
    private var imageSize: CGSize = .zero

    func setImageSize(_ size: CGSize) {
        imageSize = size
    }

    func addStroke(_ stroke: BrushStroke) {
        strokes.append(stroke)
    }

    func undo() {
        strokes.removeLast()
    }

    func clear() {
        strokes.removeAll()
    }

    func generateMask(for image: CIImage) async throws -> CIImage {
        let size = CGSize(width: image.extent.width, height: image.extent.height)
        guard size.width > 0 && size.height > 0 else {
            return CIImage(color: .black).cropped(to: image.extent)
        }
        return await Task.detached(priority: .userInitiated) { [strokes] in
            Self.renderStrokes(strokes, size: size)
        }.value
    }

    private static func renderStrokes(_ strokes: [BrushStroke], size: CGSize) -> CIImage {
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let ctx = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return CIImage(color: .black).cropped(to: CGRect(origin: .zero, size: size))
        }
        ctx.setFillColor(gray: 0, alpha: 1)
        ctx.fill(CGRect(origin: .zero, size: size))

        for stroke in strokes {
            let gray: CGFloat = stroke.isErasing ? 0 : 1
            ctx.setFillColor(gray: gray, alpha: CGFloat(stroke.opacity))
            for (i, pt) in stroke.points.enumerated() {
                if i == 0 { continue }
                let prev = stroke.points[i - 1]
                let steps = Int(max(hypot(pt.x - prev.x, pt.y - prev.y) / (CGFloat(stroke.radius) * 0.25), 1))
                for step in 0...steps {
                    let t = CGFloat(step) / CGFloat(steps)
                    let x = prev.x + (pt.x - prev.x) * t
                    let y = prev.y + (pt.y - prev.y) * t
                    let r = CGFloat(stroke.radius)
                    let softRadius = r * (1 - CGFloat(stroke.hardness) * 0.5)
                    // Outer circle for soft edges
                    ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
                }
            }
        }

        guard let cgImage = ctx.makeImage() else {
            return CIImage(color: .black).cropped(to: CGRect(origin: .zero, size: size))
        }
        return CIImage(cgImage: cgImage)
    }
}
