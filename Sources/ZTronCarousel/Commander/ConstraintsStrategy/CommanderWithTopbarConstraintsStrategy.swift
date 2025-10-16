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
    
    public final func makeTopbarConstraints(
        for orientation: UIDeviceOrientation,
        nestingLevel: Int,
        maxDepth: Int
    ) {
        guard let owner = owner else { return }
        guard owner.topbarViews.count > nestingLevel else { return }
        assert(nestingLevel < owner.topbarViews.count)
        
        let topbarView = owner.topbarViews[nestingLevel]
        
        switch nestingLevel {
            case 0:
                if maxDepth > 1 {
                    self.pinTopbarToTop(topbarView)
                } else {
                    self.pinTopbarBelowCarousel(topbarView)
                }
            
            case 1:
                self.pinTopbarBelowCarousel(topbarView)
            
            default:
                self.stackTopbarAtNestingLevel(topbarView, nestingLevel: nestingLevel)
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
        
        pgvcTop = owner.myContainerView.topAnchor.constraint(
            equalTo: owner.topbarViews.count < 2 ?
                owner.scrollView.contentLayoutGuide.topAnchor :
                    owner.topbarViews[0].view.safeAreaLayoutGuide.bottomAnchor
        )
        
        pgvcTop.isActive = true
    }
    

    public final func makeScrollViewContentConstraints(for orientation: UIDeviceOrientation) {
        guard let owner = self.owner else { return }
        
        self.scrollViewTopContentGuide = owner.scrollView.contentLayoutGuide.topAnchor.constraint(
            equalTo: (owner.topbarViews.count < 2) ?
                owner.myContainerView.topAnchor :
                owner.topbarViews[0].view.safeAreaLayoutGuide.topAnchor
        )
        
        self.scrollViewTopContentGuide?.isActive = true

        owner.scrollView.contentLayoutGuide.leftAnchor.constraint(equalTo: owner.scrollView.frameLayoutGuide.leftAnchor).isActive = true
        owner.scrollView.contentLayoutGuide.rightAnchor.constraint(equalTo: owner.scrollView.frameLayoutGuide.rightAnchor).isActive = true
    }
    
    public final func updatePageWrapperConstraintsForTransition(to orientation: UIDeviceOrientation, sizeAfterTransition: CGSize) {
        guard let owner = self.owner else { return }
        
        self.pgvcTop.isActive = false
        
        self.pgvcTop = owner.myContainerView.topAnchor.constraint(
            equalTo: owner.topbarViews.count < 2 ?
                owner.scrollView.contentLayoutGuide.topAnchor :
                    owner.topbarViews[0].view.safeAreaLayoutGuide.bottomAnchor
        )

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
        
        return owner.topbarViews.last?.view ?? owner.bottomBarView
    }
    
    
    private func pinTopbarBelowCarousel(_ topbar: UIViewController) {
        guard let owner = self.owner else { return }
        
        topbar.view.snp.makeConstraints { make in
            make.left.equalTo(owner.thePageVC.view).offset(20.0)
            make.right.equalTo(owner.thePageVC.view).offset(-20.0)
            make.top.equalTo(owner.bottomBarView.snp.bottom).offset(25.0)
            
            if topbar.view.intrinsicContentSize.height > 0 {
                make.height.equalTo(topbar.view.intrinsicContentSize.height)
            }
        }
    }
    
    private func pinTopbarToTop(_ topbar: UIViewController) {
        guard let owner = self.owner else { return }
        
        topbar.view.snp.makeConstraints { make in
            make.left.right.top.equalTo(owner.scrollView.contentLayoutGuide)
            
            if topbar.view.intrinsicContentSize.height > 0 {
                make.height.equalTo(topbar.view.intrinsicContentSize.height)
            }
        }
    }
    
    private func stackTopbarAtNestingLevel(
        _ topbar: UIViewController,
        nestingLevel: Int
    ) {
        guard let owner = self.owner else { return }
        guard owner.topbarViews.count > nestingLevel else { return }
        guard nestingLevel >= 1 else { return }
        
        let previousTopbar = owner.topbarViews[nestingLevel - 1]
        
        topbar.view.snp.makeConstraints { make in
            make.left.right.equalTo(owner.scrollView.contentLayoutGuide)
            make.top.equalTo(previousTopbar.view.snp.bottom).offset(15.0)
            
            if topbar.view.intrinsicContentSize.height > 0 {
                make.height.equalTo(topbar.view.intrinsicContentSize.height)
            }
        }
    }
}
