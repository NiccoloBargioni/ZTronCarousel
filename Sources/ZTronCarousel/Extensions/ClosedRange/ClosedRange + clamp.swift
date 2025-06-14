import Foundation

public extension ClosedRange<CGFloat> {
    func clamp(_ t: CGFloat) -> CGFloat {
        return t < self.lowerBound ? lowerBound : t < self.upperBound ? t : self.upperBound
    }
}
