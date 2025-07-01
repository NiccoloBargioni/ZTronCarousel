import UIKit

public extension UILabel {
    func animate(font: UIFont, textColor: UIColor? = nil, duration: TimeInterval) {
        
        let labelScale = self.font.pointSize / font.pointSize
        self.font = font
        let oldTransform = transform
        transform = transform.scaledBy(x: labelScale, y: labelScale)

        setNeedsUpdateConstraints()
        UIView.animate(withDuration: duration) {
            //L self.frame.origin = newOrigin
            self.transform = oldTransform
            self.layoutIfNeeded()
            
            if let textColor = textColor {
                self.textColor = textColor
            }
        }
    }
}
