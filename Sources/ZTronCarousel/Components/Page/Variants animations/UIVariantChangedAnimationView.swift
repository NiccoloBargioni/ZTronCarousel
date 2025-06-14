import UIKit
import ZTronObservation


public final class UIVariantChangedForwardAnimation: UIView, VariantAnimation {
    private let initialNormalizedAABB: CGRect
    private let hostedImage: UIImageView
    private let completion: ((_ ended: Bool) -> Void)?
    
    private let target: String
    
    @MainActor private(set) public var status: UIVariantChangedForwardAnimation.Status = .ready
    
    private var hostedImageTopConstraint: NSLayoutConstraint?
    private var hostedImageLeftConstraint: NSLayoutConstraint?
    private var hostedImageWidthConstraint: NSLayoutConstraint?
    private var hostedImageHeightConstraint: NSLayoutConstraint?
    
    
    private var theAnimation: UIViewPropertyAnimator? = nil
    
    
    public init(target: String, bundle: Bundle?, initialNormalizedAABB: CGRect, completion: (((_ ended: Bool) -> Void))? = nil) {
        self.initialNormalizedAABB = initialNormalizedAABB
        
        guard let image = UIImage(named: target, in: bundle, with: nil) else { fatalError() }
        let hostedImage = UIImageView(image: image)
        hostedImage.contentMode = .scaleAspectFit
        
        self.hostedImage = hostedImage
        self.completion = completion
        
        self.target = target
        super.init(frame: .zero)

        self.addSubview(hostedImage)
                
        self.hostedImage.translatesAutoresizingMaskIntoConstraints = false
        hostedImageTopConstraint = self.hostedImage.topAnchor.constraint(equalTo: self.safeAreaLayoutGuide.topAnchor)
        hostedImageLeftConstraint = self.hostedImage.leftAnchor.constraint(equalTo: self.safeAreaLayoutGuide.leftAnchor)
        hostedImageWidthConstraint = self.hostedImage.widthAnchor.constraint(equalTo: self.safeAreaLayoutGuide.widthAnchor, multiplier: initialNormalizedAABB.width)
        hostedImageHeightConstraint = self.hostedImage.heightAnchor.constraint(equalTo: self.safeAreaLayoutGuide.heightAnchor, multiplier: initialNormalizedAABB.height)

        NSLayoutConstraint.activate([
            hostedImageTopConstraint!, hostedImageLeftConstraint!, hostedImageWidthConstraint!, hostedImageHeightConstraint!
        ])
        
        self.hostedImage.layer.borderColor = UIColor.red.cgColor
        self.hostedImage.layer.borderWidth = 1.0
        
        self.hostedImage.isHidden = true
        // self.alpha = 0.0
    }
    
    required init(coder: NSCoder) {
        fatalError("Cannot load from Storyboard")
    }
    
    
    public final func start() {
        self.status = .started
        
        let sizeThatFits = CGSize.sizeThatFits(
            containerSize: .init(
                width: self.bounds.size.width * self.initialNormalizedAABB.width,
                height: self.bounds.size.height * self.initialNormalizedAABB.height
            ),
            containedAR: 16.0/9.0
        )
        
        self.hostedImage.isHidden = false

        self.parentViewController?.view.layer.removeAllAnimations()
        self.parentViewController?.view.layoutIfNeeded()
        
        UIView.animate(withDuration: 0.25) {
            self.hostedImageLeftConstraint?.isActive = false
            self.hostedImageLeftConstraint = self.hostedImage.leftAnchor.constraint(
                equalTo: self.safeAreaLayoutGuide.leftAnchor,
                constant: self.bounds.size.width * self.initialNormalizedAABB.origin.x
            )
            self.hostedImageLeftConstraint?.isActive = true
            
            self.hostedImageTopConstraint?.isActive = false
            self.hostedImageTopConstraint = self.hostedImage.topAnchor.constraint(
                equalTo: self.safeAreaLayoutGuide.topAnchor,
                constant: self.bounds.size.height * self.initialNormalizedAABB.origin.y
            )
            self.hostedImageTopConstraint?.isActive = true
            
            self.hostedImageWidthConstraint?.isActive = false
            self.hostedImageWidthConstraint = self.hostedImage.widthAnchor.constraint(equalToConstant: sizeThatFits.width)
            self.hostedImageWidthConstraint?.isActive = true
            
            self.hostedImageHeightConstraint?.isActive = false
            self.hostedImageHeightConstraint = self.hostedImage.heightAnchor.constraint(equalToConstant: sizeThatFits.height)
            self.hostedImageHeightConstraint?.isActive = true

            // self.alpha = 1.0
            
            self.layoutIfNeeded()
        } completion: { animationEnded in
            UIView.animate(withDuration: 0.75, delay: 0.5) {
                self.hostedImageTopConstraint?.isActive = false
                self.hostedImageTopConstraint = self.hostedImage.topAnchor.constraint(equalTo: self.hostedImage.superview!.safeAreaLayoutGuide.topAnchor)
                self.hostedImageTopConstraint?.isActive = true
                
                self.hostedImageLeftConstraint?.isActive = false
                self.hostedImageLeftConstraint = self.hostedImage.leftAnchor.constraint(equalTo: self.hostedImage.superview!.safeAreaLayoutGuide.leftAnchor)
                self.hostedImageLeftConstraint?.isActive = true
        
                self.hostedImageWidthConstraint?.isActive = false
                self.hostedImageWidthConstraint = self.hostedImage.widthAnchor.constraint(equalTo: self.hostedImage.superview!.safeAreaLayoutGuide.widthAnchor)
                self.hostedImageWidthConstraint?.isActive = true
                
                self.hostedImageHeightConstraint?.isActive = false
                self.hostedImageHeightConstraint = self.hostedImage.heightAnchor.constraint(equalTo: self.hostedImage.superview!.safeAreaLayoutGuide.heightAnchor)
                self.hostedImageHeightConstraint?.isActive = true
                
                self.layoutIfNeeded()
            } completion: { ended in
                self.status = .completed
                self.theAnimation = nil
                self.completion?(ended)
            }
        }
    }
    
    public enum Status: Sendable {
        case ready
        case failed
        case started
        case completed
    }
}
