import UIKit

public extension UIScrollView {
    func centerScrollContent(_ view: UIView) {
        let scrollWidth = self.frame.width
        let desiredXCoor = view.frame.origin.x - ((scrollWidth / 2) - (view.frame.width / 2))
        let rect = CGRect(x: desiredXCoor, y: 0, width: scrollWidth, height: self.frame.height)
        self.scrollRectToVisible(rect, animated: true)
    }
}
