import SwiftSVG
import QuartzCore

public extension SVGLayerType where Self: CALayer {
    /// Scales a layer to aspect FILL the given rect (crops instead of letterboxing).
    ///
    /// Mutating a `CALayer` is main-thread work and `CALayer` is not `Sendable`, so the
    /// method is isolated to the main actor instead of hopping to the main queue itself.
    @discardableResult
    @MainActor
    func resizeToFill(_ rect: CGRect) -> Self {
        let widthScale  = rect.width  / self.boundingBox.width
        let heightScale = rect.height / self.boundingBox.height
        let scaleFactor = max(widthScale, heightScale)
        let scaleTransform = CGAffineTransform(scaleX: scaleFactor, y: scaleFactor)

        self.setAffineTransform(scaleTransform)
        return self
    }
}
