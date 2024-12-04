import UIKit
import ZTronObservation

fileprivate extension ClosedRange<CGFloat> {
    func larp(_ t: CGFloat) -> CGFloat {
        return self.lowerBound + t*(self.upperBound - self.lowerBound)
    }
}


public final class UIVariantChangeGoBackAnimation: UIView, VariantAnimation {
    private let initialNormalizedAABB: CGRect
    private let slaveImage: UIImageView
    private let masterImage: UIImageView
    private let completion: ((_ completed: Bool) -> Void)?
    
    private var slaveLeftConstraint: NSLayoutConstraint!
    private var slaveTopConstraint: NSLayoutConstraint!
    private var slaveWidthConstraint: NSLayoutConstraint!
    private var slaveHeightConstraint: NSLayoutConstraint!
    
    @MainActor private(set) public var status: UIVariantChangedForwardAnimation.Status = .ready
    
    private let master: String
    private let slave: String
    
    private var fractionCompleted: CGFloat = 0
    
    private var theAnimation: UIViewPropertyAnimator? = nil
        
    public init(master: String, slave: String, bundle: Bundle?, initialNormalizedAABB: CGRect, completion: ((_ completed: Bool) -> Void)? = nil) {
        self.initialNormalizedAABB = initialNormalizedAABB
        self.master = master
        self.slave = slave

        guard let slave = UIImage(named: slave, in: bundle, with: nil) else { fatalError() }
        let slaveImage = UIImageView(image: slave)
        slaveImage.contentMode = .scaleAspectFit
        
        
        guard let master = UIImage(named: master, in: bundle, with: nil) else { fatalError() }
        let masterImage = UIImageView(image: master)
        masterImage.contentMode = .scaleAspectFit
        
        self.slaveImage = slaveImage
        self.masterImage = masterImage
        self.completion = completion
                
        super.init(frame: .zero)
        self.layoutIfNeeded()
        
        self.backgroundColor = .red
        self.addSubview(self.masterImage)
        self.masterImage.snp.makeConstraints { make in
            make.top.right.bottom.left.equalToSuperview()
        }
        
        self.addSubview(slaveImage)
        
        slaveImage.translatesAutoresizingMaskIntoConstraints = false
        self.slaveTopConstraint = slaveImage.topAnchor.constraint(equalTo: self.topAnchor)
        self.slaveLeftConstraint = slaveImage.leftAnchor.constraint(equalTo: self.leftAnchor)
        self.slaveWidthConstraint = slaveImage.widthAnchor.constraint(equalTo: self.widthAnchor)
        self.slaveHeightConstraint = slaveImage.heightAnchor.constraint(equalTo: self.heightAnchor)
        
        self.slaveTopConstraint.isActive = true
        self.slaveLeftConstraint.isActive = true
        self.slaveWidthConstraint.isActive = true
        self.slaveHeightConstraint.isActive = true
        
        slaveImage.layer.borderColor = UIColor.red.cgColor
        slaveImage.layer.borderWidth = 1.0
    }
    
    required init(coder: NSCoder) {
        fatalError("Cannot load from Storyboard")
    }

    
    public final func start() {
        self.makeTheAnimation()

        self.theAnimation?.startAnimation()
        
        let startTime = DispatchTime.now()
        self.theAnimation?.addCompletion { animation in
            if animation == .end {
                self.status = .completed
                self.completion?(animation == .end)
            }
        }
    }

    private final func makeTheAnimation() {
        let sizeThatFits = CGSize.sizeThatFits(
            containerSize: .init(
                width: self.bounds.size.width * self.initialNormalizedAABB.width,
                height: self.bounds.size.height * self.initialNormalizedAABB.height
            ),
            containedAR: 16.0/9.0
        )
        

        self.theAnimation = UIViewPropertyAnimator(duration: 0.5, curve: .linear) {
            self.slaveTopConstraint.isActive = false
            self.slaveTopConstraint = self.slaveImage.topAnchor.constraint(
                equalTo: self.topAnchor,
                constant: self.bounds.size.height * self.initialNormalizedAABB.origin.y
            )
            self.slaveTopConstraint.isActive = true
            
            self.slaveLeftConstraint.isActive = false
            self.slaveLeftConstraint = self.slaveImage.leftAnchor.constraint(
                equalTo: self.leftAnchor,
                constant: self.bounds.size.width * self.initialNormalizedAABB.origin.x
            )
            self.slaveLeftConstraint.isActive = true

            self.slaveWidthConstraint.isActive = false
            self.slaveWidthConstraint = self.slaveImage.widthAnchor.constraint(
                equalToConstant: sizeThatFits.width
            )
            self.slaveWidthConstraint.isActive = true

            self.slaveHeightConstraint.isActive = false
            self.slaveHeightConstraint = self.slaveImage.heightAnchor.constraint(
                equalToConstant: sizeThatFits.height
            )
            self.slaveHeightConstraint.isActive = true
            
            self.layoutIfNeeded()
        }
    }

    public func detach() {
        UIView.animate(withDuration: 0.25) {
            self.alpha = 0.0
        } completion: { ended in
            if ended {
                self.removeFromSuperview()
            } else {
                DispatchQueue.main.async {
                    Task(priority: .userInitiated) { @MainActor in
                        self.removeFromSuperview()
                    }
                }
            }
        }
    }
    
    public func viewWillTransitionTo(size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        guard let theAnimation = self.theAnimation else { return }
        self.layoutIfNeeded()
        
        if theAnimation.isRunning {
            theAnimation.pauseAnimation()
            self.fractionCompleted = theAnimation.fractionComplete
            theAnimation.stopAnimation(true)
        }
        
        if self.fractionCompleted > 0 && self.fractionCompleted < 1 {
            
            UIView.animate(withDuration: 0.05) {
                self.slaveTopConstraint.isActive = false
                self.slaveTopConstraint = self.slaveImage.topAnchor.constraint(
                    equalTo: self.slaveImage.superview!.topAnchor,
                    constant: (0...self.bounds.size.height * self.initialNormalizedAABB.origin.y).larp(self.fractionCompleted)
                )
                self.slaveTopConstraint.isActive = true
                
                self.slaveLeftConstraint.isActive = false
                self.slaveLeftConstraint = self.slaveImage.leftAnchor.constraint(
                    equalTo: self.leftAnchor,
                    constant: (0...self.bounds.size.width * self.initialNormalizedAABB.origin.x).larp(self.fractionCompleted)
                )
                self.slaveLeftConstraint.isActive = true
                
                self.slaveWidthConstraint.isActive = false
                self.slaveWidthConstraint = self.slaveImage.widthAnchor.constraint(
                    equalTo: self.slaveImage.superview!.widthAnchor,
                    multiplier: (self.initialNormalizedAABB.width...1).larp(1 - self.fractionCompleted)
                )
                self.slaveWidthConstraint.isActive = true
                
                self.slaveHeightConstraint.isActive = false
                self.slaveHeightConstraint = self.slaveImage.heightAnchor.constraint(
                    equalTo: self.slaveImage.superview!.heightAnchor,
                    multiplier: (self.initialNormalizedAABB.height...1).larp(1 - self.fractionCompleted)
                )
                self.slaveHeightConstraint.isActive = true
                
                self.layoutIfNeeded()
            }
        }
            
        
        self.status = .ready
        self.start()
    }
    
    public enum Status: Sendable {
        case ready
        case started
        case completed
    }
}


fileprivate extension DispatchTimeInterval {
    func toDouble() -> Double? {
        var result: Double? = 0

        switch self {
        case .seconds(let value):
            result = Double(value)
        case .milliseconds(let value):
            result = Double(value)*0.001
        case .microseconds(let value):
            result = Double(value)*0.000001
        case .nanoseconds(let value):
            result = Double(value)*0.000000001

        case .never:
            result = nil
            
        @unknown default:
            break
        }

        return result
    }
}

