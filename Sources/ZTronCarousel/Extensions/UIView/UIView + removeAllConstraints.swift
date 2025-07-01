import UIKit

public extension UIView {
    
    func removeAllConstraints() {
        var _superview = self.superview
        
        while let superview = _superview {
            for constraint in superview.constraints {
                
                if let first = constraint.firstItem as? UIView, first == self {
                    superview.removeConstraint(constraint)
                }
                
                if let second = constraint.secondItem as? UIView, second == self {
                    superview.removeConstraint(constraint)
                }
            }
            
            _superview = superview.superview
        }
        
        self.removeConstraints(self.constraints)
        self.translatesAutoresizingMaskIntoConstraints = true
    }
    
    func removeAllSubviewsConstraints() {
        self._removeAllSubviewsContraints(self.subviews)
    }
    
    private func _removeAllSubviewsContraints(_ views: [UIView]) {
        for view in views {
            view.removeConstraints(view.constraints)
            _removeAllSubviewsContraints(view.subviews)
        }
    }
}

