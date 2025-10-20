import UIKit

public extension UIView {
    private func involvesRightAnchor(_ constraint: NSLayoutConstraint) -> Bool {
        return constraint.firstAnchor == self.rightAnchor ||
               constraint.secondAnchor == self.rightAnchor
    }
    
    private func involvesLeftAnchor(_ constraint: NSLayoutConstraint) -> Bool {
        return constraint.firstAnchor == self.leftAnchor ||
               constraint.secondAnchor == self.leftAnchor
    }
    
    func removeAllRightAnchorConstraints() {
        for constraint in self.constraints {
            if involvesRightAnchor(constraint) {
                self.removeConstraint(constraint)
            }
        }

        var removedConstraintsCount: Int = .zero
        var currentSuperview = self.superview
        while let superview = currentSuperview {
            for constraint in superview.constraints {
                let involvesThisView =
                    (constraint.firstItem as? UIView) == self ||
                    (constraint.secondItem as? UIView) == self

                if involvesThisView && involvesRightAnchor(constraint) {
                    superview.removeConstraint(constraint)
                    removedConstraintsCount += 1
                }
            }
            
            currentSuperview = superview.superview
        }        
    }
    
    func removeAllLeftAnchorConstraints() {
        for constraint in self.constraints {
            if involvesLeftAnchor(constraint) {
                self.removeConstraint(constraint)
            }
        }

        var removedConstraintsCount: Int = .zero
        var currentSuperview = self.superview
        while let superview = currentSuperview {
            for constraint in superview.constraints {
                let involvesThisView =
                    (constraint.firstItem as? UIView) == self ||
                    (constraint.secondItem as? UIView) == self

                if involvesThisView && involvesLeftAnchor(constraint) {
                    superview.removeConstraint(constraint)
                    removedConstraintsCount += 1
                }
            }
            
            currentSuperview = superview.superview
        }
    }
}
