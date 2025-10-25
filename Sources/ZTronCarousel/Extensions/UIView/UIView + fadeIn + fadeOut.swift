import UIKit

internal extension UIView {
    func fadeOut(_ completion: (() -> Void)? = nil) -> Void {
        self.subviews.forEach { subview in
            UIView.animate(withDuration: 0.25) {
                subview.layer.opacity = 0
            } completion: { _ in
                subview.isHidden = true
            }
        }
        
        UIView.animate(withDuration: 0.25) {
            self.layer.opacity = 0
        } completion: { _ in
            self.isHidden = true
            completion?()
        }
    }
    
    
    func fadeIn(_ completion: (() -> Void)? = nil) -> Void {
        self.isHidden = false
        UIView.animate(withDuration: 0.25) {
            self.layer.opacity = 1
        }

        self.subviews.forEach { subview in
            subview.layer.isHidden = false

            UIView.animate(withDuration: 0.25) {
                subview.layer.opacity = 1
                completion?()
            }
        }

    }
}
