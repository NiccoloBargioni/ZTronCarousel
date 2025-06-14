import Foundation

public extension ClosedRange<CGFloat> {
    func easeIn(_ t: CGFloat) -> CGFloat {
        return t*t
    }
}
