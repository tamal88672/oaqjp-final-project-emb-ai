import SwiftUI
import UIKit

/// Transparent overlay capturing raw touch input for brush masking.
/// Uses UIView directly (not gesture recognizers) to minimize latency.
struct BrushCanvasView: UIViewRepresentable {
    @EnvironmentObject var maskingVM: MaskingViewModel

    /// Transform from view coords to image coords, considering zoom/pan.
    var viewToImageTransform: CGAffineTransform = .identity

    func makeUIView(context: Context) -> BrushCanvasUIView {
        let view = BrushCanvasUIView()
        view.onBegin = { Task { @MainActor in maskingVM.beginBrushStroke() } }
        view.onPoint = { pt in Task { @MainActor in await maskingVM.addBrushPoint(pt) } }
        view.onEnd   = { Task { @MainActor in await maskingVM.endBrushStroke() } }
        view.transform = viewToImageTransform.inverted()
        return view
    }

    func updateUIView(_ uiView: BrushCanvasUIView, context: Context) {}
}

final class BrushCanvasUIView: UIView {
    var onBegin: (() -> Void)?
    var onPoint: ((CGPoint) -> Void)?
    var onEnd: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isMultipleTouchEnabled = false
    }

    required init?(coder: NSCoder) { fatalError() }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        onBegin?()
        if let pt = touches.first?.location(in: self) { onPoint?(pt) }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        // Use predicted touches for smoother stroke
        if let predicted = event?.predictedTouches(for: touch) {
            for t in predicted { onPoint?(t.location(in: self)) }
        } else {
            onPoint?(touch.location(in: self))
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { onEnd?() }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { onEnd?() }
}
