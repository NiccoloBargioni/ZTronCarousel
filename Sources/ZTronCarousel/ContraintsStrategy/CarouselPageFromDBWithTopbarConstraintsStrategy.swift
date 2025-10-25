import UIKit
import SnapKit

public final class CarouselPageFromDBWithTopbarConstraintsStrategy: CarouselWithTopbarConstraintsStrategy {
    weak public var owner: CarouselPageFromDB?
    
    private var pgvcHeight: NSLayoutConstraint!
    private var pgvcWidth: NSLayoutConstraint!
    private var pgvcTop: NSLayoutConstraint!

    private var scrollViewTopContentGuide: NSLayoutConstraint?

    public init(owner: CarouselPageFromDB) {
        self.owner = owner
    }
    
    public final func makeTopbarConstraints(
        for orientation: UIDeviceOrientation,
        nestingLevel: Int,
        maxDepth: Int
    ) {
        guard let owner = owner else { return }
        guard maxDepth > 0 else { return }
        assert(maxDepth >= nestingLevel)
        assert(nestingLevel < owner.topbarViews.count)
        guard owner.topbarViews.count > nestingLevel else { return }
        
        let topbarView = owner.topbarViews[nestingLevel]
        
        if nestingLevel == 0 {
            topbarView.view.snp.makeConstraints { make in
                make.left.right.top.equalTo(owner.scrollView.contentLayoutGuide)
                
                if topbarView.view.intrinsicContentSize.height > 0 {
                    make.height.equalTo(topbarView.view.intrinsicContentSize.height)
                }
            }
        } else {
            if nestingLevel == 1 {
                topbarView.view.snp.makeConstraints { make in
                    make.left.equalTo(owner.thePageVC.view)
                    make.right.equalTo(owner.thePageVC.view)
                    make.top.equalTo(owner.bottomBarView.snp.bottom).offset(25.0)
                    
                    if topbarView.view.intrinsicContentSize.height > 0 {
                        make.height.equalTo(topbarView.view.intrinsicContentSize.height)
                    }
                }
            } else {
                let previousTopbar = owner.topbarViews[nestingLevel - 1]
                
                topbarView.view.snp.makeConstraints { make in
                    make.left.equalTo(owner.thePageVC.view)
                    make.right.equalTo(owner.thePageVC.view)
                    make.top.equalTo(previousTopbar.view.snp.bottom)
                    
                    if topbarView.view.intrinsicContentSize.height > 0 {
                        make.height.equalTo(topbarView.view.intrinsicContentSize.height)
                    }
                }
            }
        }
        
        
    }
    
    public final func makePageWrapperConstraints(for orientation: UIDeviceOrientation) {
        guard let owner = self.owner else { return }
        guard let topbarView = owner.topbarViews.first else { return }
        
        let size = owner.computeContentSizeThatFits()
        owner.myContainerView.translatesAutoresizingMaskIntoConstraints = false

        owner.myContainerView.snp.makeConstraints { make in
            make.centerX.equalTo(owner.view.safeAreaLayoutGuide)
        }
        
        pgvcHeight = owner.myContainerView.heightAnchor.constraint(equalToConstant: size.height)
        pgvcHeight.isActive = true

        pgvcWidth = owner.myContainerView.widthAnchor.constraint(equalToConstant: size.width)
        pgvcWidth.isActive = true
        
        pgvcTop = owner.myContainerView.topAnchor.constraint(equalTo: topbarView.view.safeAreaLayoutGuide.bottomAnchor)
        
        pgvcTop.isActive = true
    }
    

    public final func makeScrollViewContentConstraints(for orientation: UIDeviceOrientation) {
        guard let owner = self.owner else { return }
        guard let topbarView = owner.topbarViews.first else { return }
        
        self.scrollViewTopContentGuide = owner.scrollView.contentLayoutGuide.topAnchor.constraint(
            equalTo: orientation.isPortrait ?
            topbarView.view.safeAreaLayoutGuide.topAnchor :
                owner.myContainerView.safeAreaLayoutGuide.topAnchor
        )
        
        self.scrollViewTopContentGuide?.isActive = true

        owner.scrollView.contentLayoutGuide.leftAnchor.constraint(equalTo: owner.scrollView.frameLayoutGuide.leftAnchor).isActive = true
        owner.scrollView.contentLayoutGuide.rightAnchor.constraint(equalTo: owner.scrollView.frameLayoutGuide.rightAnchor).isActive = true
    }
    
    public final func updatePageWrapperConstraintsForTransition(to orientation: UIDeviceOrientation, sizeAfterTransition: CGSize) {
        guard let owner = self.owner else { return }
        guard let topbarView = owner.topbarViews.first else { return }
        
        self.pgvcTop.isActive = false
        
        if sizeAfterTransition.width < sizeAfterTransition.height {
            self.pgvcTop = owner.myContainerView.topAnchor.constraint(equalTo: topbarView.view.bottomAnchor)
        } else {
            self.pgvcTop = owner.myContainerView.topAnchor.constraint(equalTo: owner.view.safeAreaLayoutGuide.topAnchor)
        }
        
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
        guard let owner = self.owner else { return }
        guard let topbarView = owner.topbarViews.first else { return }
        
        self.scrollViewTopContentGuide?.isActive = false
        if orientation.isPortrait {
            self.scrollViewTopContentGuide = owner.scrollView.contentLayoutGuide.topAnchor.constraint(equalTo: topbarView.view.safeAreaLayoutGuide.topAnchor)
        }
        
        self.scrollViewTopContentGuide?.isActive = true
    }
    
    public func viewBelowCarousel() -> UIView {
        guard let owner = self.owner else { fatalError() }
        return owner.captionView.superview!
    }

}
