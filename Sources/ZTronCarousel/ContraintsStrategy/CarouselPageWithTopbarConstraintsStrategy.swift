import UIKit
import SnapKit

internal final class CarouselPageWithTopbarConstraintsStrategy: ConstraintsStrategy {
    weak internal var owner: CarouselPageWithTopbar?
    
    private var pgvcHeight: NSLayoutConstraint!
    private var pgvcWidth: NSLayoutConstraint!
    private var pgvcTop: NSLayoutConstraint!

    private var scrollViewTopContentGuide: NSLayoutConstraint!

    public init(owner: CarouselPageWithTopbar) {
        self.owner = owner
    }
    
    func makeTopbarConstraints(for orientation: UIDeviceOrientation) {
        guard let owner = owner else { return }
        
        owner.topbarView.view.snp.makeConstraints { make in
            make.left.right.top.equalTo(owner.scrollView.contentLayoutGuide)
            make.height.equalTo(owner.topbarView.view.intrinsicContentSize.height)
        }

    }
    
    func makePageWrapperConstraints(for orientation: UIDeviceOrientation) {
        guard let owner = self.owner else { return }
        let size = owner.computeContentSizeThatFits()
        
        owner.myContainerView.snp.makeConstraints { make in
            make.centerX.equalTo(owner.view.safeAreaLayoutGuide)
        }

        
        pgvcHeight = owner.myContainerView.heightAnchor.constraint(equalToConstant: size.height)
        pgvcHeight.isActive = true

        pgvcWidth = owner.myContainerView.widthAnchor.constraint(equalToConstant: size.width)
        pgvcWidth.isActive = true
        
        pgvcTop = owner.myContainerView.topAnchor.constraint(equalTo: owner.topbarView.view.safeAreaLayoutGuide.bottomAnchor)
        pgvcTop.isActive = true

    }
    

    func makeScrollViewContentConstraints(for orientation: UIDeviceOrientation) {
        guard let owner = self.owner else { return }
        
        self.scrollViewTopContentGuide = owner.scrollView.contentLayoutGuide.topAnchor.constraint(
            equalTo: orientation.isPortrait ?
                owner.topbarView.view.safeAreaLayoutGuide.topAnchor :
                owner.myContainerView.safeAreaLayoutGuide.topAnchor
        )
        self.scrollViewTopContentGuide.isActive = true

        owner.scrollView.contentLayoutGuide.leftAnchor.constraint(equalTo: owner.scrollView.frameLayoutGuide.leftAnchor).isActive = true
        owner.scrollView.contentLayoutGuide.rightAnchor.constraint(equalTo: owner.scrollView.frameLayoutGuide.rightAnchor).isActive = true
    }
    
    func updatePageWrapperConstraintsForTransition(to orientation: UIDeviceOrientation, sizeAfterTransition: CGSize) {
        guard let owner = self.owner else { return }
        
        if orientation.isLandscape {
            self.pgvcTop.isActive = false
            self.pgvcTop = owner.myContainerView.topAnchor.constraint(equalTo: owner.scrollView.contentLayoutGuide.topAnchor)
            self.pgvcTop.isActive = true
        } else {
            self.pgvcTop.isActive = false
            self.pgvcTop = owner.myContainerView.topAnchor.constraint(equalTo: owner.topbarView.view.bottomAnchor)
            self.pgvcTop.isActive = true
        }
        
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
    
    func updateScrollViewContentConstraintsForTransition(to orientation: UIDeviceOrientation, sizeAfterTransition: CGSize) {
        guard let owner = self.owner else { return }
        
        if orientation.isPortrait {
            self.scrollViewTopContentGuide.isActive = false
            self.scrollViewTopContentGuide = owner.scrollView.contentLayoutGuide.topAnchor.constraint(equalTo: owner.topbarView.view.safeAreaLayoutGuide.topAnchor)
            self.scrollViewTopContentGuide.isActive = true
        }
    }
}
