import UIKit

internal extension UIView {
    /// Shows or hides the small lock glyph that marks a bottom-bar item as paywalled, pinned to
    /// the item's bottom-right corner. Idempotent: the badge is created once, then toggled and
    /// re-tinted. The badge never intercepts touches, so the tap still reaches the item (and gets
    /// gated by `PaywallGate`, which presents the prompt).
    func setPaywallLockBadge(_ visible: Bool, color: UIColor) {
        let identifier = "ztron.paywall.lock.badge"
        let existing = self.subviews.first { $0.accessibilityIdentifier == identifier } as? UIImageView
        
        guard visible else {
            existing?.isHidden = true
            return
        }
        
        let badge: UIImageView
        
        if let existing = existing {
            badge = existing
        } else {
            badge = UIImageView(
                image: UIImage(systemName: "lock.fill")?
                    .withConfiguration(UIImage.SymbolConfiguration(pointSize: 8, weight: .bold))
            )
            
            badge.accessibilityIdentifier = identifier
            badge.contentMode = .scaleAspectFit
            badge.isUserInteractionEnabled = false
            badge.layer.zPosition = 2
            
            self.addSubview(badge)
            badge.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                badge.rightAnchor.constraint(equalTo: self.rightAnchor, constant: 1),
                badge.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: 1)
            ])
        }
        
        badge.tintColor = color
        badge.isHidden = false
    }
}
