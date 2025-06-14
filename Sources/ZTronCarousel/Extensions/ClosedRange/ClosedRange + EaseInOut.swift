import Foundation

public extension ClosedRange<CGFloat> {
    func easeInOut(_ t: CGFloat) -> CGFloat {
        return (self.easeIn(t)...self.easeOut(t)).larp(t)
    }
}
