import UIKit
import SnapKit

public final class CommanderWithTopbarConstraintsStrategy: CarouselWithTopbarConstraintsStrategy {
    weak public var owner: CarouselPageFromDB?
    
    private var pgvcHeight: NSLayoutConstraint!
    private var pgvcWidth: NSLayoutConstraint!
    private var pgvcTop: NSLayoutConstraint!

    private var scrollViewTopContentGuide: NSLayoutConstraint?

    public init(owner: CarouselPageFromDB) {
        self.owner = owner
    }
    
    public final func makeTopbarConstraints(for orientation: UIDeviceOrientation) {
        guard let owner = owner else { return }
        guard let topbarView = owner.topbarView else { return }
        
        topbarView.view.snp.makeConstraints { make in
            make.left.right.equalTo(owner.thePageVC.view)
            make.top.equalTo(owner.bottomBarView.snp.bottom)
            
            if topbarView.view.intrinsicContentSize.height > 0 {
                make.height.equalTo(topbarView.view.intrinsicContentSize.height)
            }
        }
    }
    
    public final func makePageWrapperConstraints(for orientation: UIDeviceOrientation) {
        guard let owner = self.owner else { return }
        
        let size = owner.computeContentSizeThatFits()
        owner.myContainerView.translatesAutoresizingMaskIntoConstraints = false

        owner.myContainerView.snp.makeConstraints { make in
            make.centerX.equalTo(owner.view.safeAreaLayoutGuide)
        }
        
        pgvcHeight = owner.myContainerView.heightAnchor.constraint(equalToConstant: size.height)
        pgvcHeight.isActive = true

        pgvcWidth = owner.myContainerView.widthAnchor.constraint(equalToConstant: size.width)
        pgvcWidth.isActive = true
        
        pgvcTop = owner.myContainerView.topAnchor.constraint(equalTo: owner.scrollView.contentLayoutGuide.topAnchor)
        
        pgvcTop.isActive = true
    }
    

    public final func makeScrollViewContentConstraints(for orientation: UIDeviceOrientation) {
        guard let owner = self.owner else { return }
        
        self.scrollViewTopContentGuide = owner.scrollView.contentLayoutGuide.topAnchor.constraint(
            equalTo: owner.myContainerView.topAnchor
        )
        
        self.scrollViewTopContentGuide?.isActive = true

        owner.scrollView.contentLayoutGuide.leftAnchor.constraint(equalTo: owner.scrollView.frameLayoutGuide.leftAnchor).isActive = true
        owner.scrollView.contentLayoutGuide.rightAnchor.constraint(equalTo: owner.scrollView.frameLayoutGuide.rightAnchor).isActive = true
    }
    
    public final func updatePageWrapperConstraintsForTransition(to orientation: UIDeviceOrientation, sizeAfterTransition: CGSize) {
        guard let owner = self.owner else { return }
        
        self.pgvcTop.isActive = false
        
        self.pgvcTop = owner.myContainerView.topAnchor.constraint(equalTo: owner.scrollView.contentLayoutGuide.topAnchor)

        self.pgvcTop.isActive = true
        
        self.pgvcHeight.isActive = false
        self.pgvcWidth.isActive = false
        
        if sizeAfterTransition.width / sizeAfterTransition.height >= 16.0/9.0 {
            self.pgvcHeight = owner.myContainerView.heightAnchor.constraint(equalTo: owner.myContainerView.superview!.safeAreaLayoutGuide.heightAnchor)
            self.pgvcWidth = owner.myContainerView.widthAnchor.constraint(equalTo: owner.myContainerView.heightAnchor, multiplier: 16.0/9.0)
        } else {
            self.pgvcWidth = owner.myContainerView.widthAnchor.constraint(equalTo: owner.myContainerView.superview!.safeAreaLayoutGuide.widthAnchor)
            self.pgvcHeight = owner.myContainerView.heightAnchor.constraint(equalTo: owner.myContainerView.widthAnchor, multiplier: 9.0/16.0)
        }
        
        self.pgvcHeight.isActive = true
        self.pgvcWidth.isActive = true
    }
    
    public final func updateScrollViewContentConstraintsForTransition(to orientation: UIDeviceOrientation, sizeAfterTransition: CGSize) {
        
    }
    
    public func viewBelowCarousel() -> UIView {
        guard let owner = self.owner else { fatalError() }
        return owner.topbarView?.view ?? owner.bottomBarView
    }
}
