import Foundation
import QuartzCore

public extension ClosedRange<CGFloat> {
    func pow(_ t: CGFloat, exp: CGFloat) -> CGFloat {
        return QuartzCore.pow(t, exp)
    }
}
