import Foundation

public extension ClosedRange<CGFloat> {
    func flip(_ t: CGFloat) -> CGFloat {
        return 1 - t
    }
}
