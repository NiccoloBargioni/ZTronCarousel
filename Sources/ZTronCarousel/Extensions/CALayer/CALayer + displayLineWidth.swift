import SwiftSVG
import QuartzCore

extension SVGLayer {
    /// Sets lineWidth on every sublayer so the stroke renders at `width` points
    /// on screen, regardless of any aspect-fit scale resizeToFit already applied.
    func setDisplayLineWidth(_ width: CGFloat) {
        let scale = self.affineTransform().a   // resizeToFit always scales x/y uniformly
        guard scale != 0 else { return }
        self.applyOnSublayers(ofType: CAShapeLayer.self) { $0.lineWidth = width / scale }
    }
}
