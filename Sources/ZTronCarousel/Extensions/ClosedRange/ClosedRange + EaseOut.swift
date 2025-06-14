import Foundation

public extension ClosedRange<CGFloat> {
    func easeOut(_ t: CGFloat) -> CGFloat {
        return self.flip(self.easeIn(self.flip(t)))
    }
}
