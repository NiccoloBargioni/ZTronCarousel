import UIKit


public final class UIDimmingBackgroundButton: UIButton {
    override public var isHighlighted: Bool {
        didSet {
            alpha = isHighlighted ? 0.4 : 1
        }
    }
}
