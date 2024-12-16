import UIKit
import SnapKit

internal final class CarouselPageFromDBConstraintsStrategy: ConstraintsStrategy {
    weak internal var owner: CarouselPageFromDB?
    
    private var pgvcHeight: NSLayoutConstraint!
    private var pgvcWidth: NSLayoutConstraint!
    private var pgvcTop: NSLayoutConstraint!

    private var scrollViewTopContentGuide: NSLayoutConstraint!

    public init(owner: CarouselPageFromDB) {
        self.owner = owner
    }
    
    func makeTopbarConstraints(for orientation: UIDeviceOrientation) {
        guard let owner = owner else { return }
        guard let topbarView = owner.topbarView else { return }
        
        topbarView.view.snp.makeConstraints { make in
            make.left.right.top.equalTo(owner.scrollView.contentLayoutGuide)
            make.height.equalTo(topbarView.view.intrinsicContentSize.height)
        }

    }
    
    func makePageWrapperConstraints(for orientation: UIDeviceOrientation) {
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
        
        if let topbarView = owner.topbarView {
            pgvcTop = owner.myContainerView.topAnchor.constraint(equalTo: topbarView.view.safeAreaLayoutGuide.bottomAnchor)
        } else {
            pgvcTop = owner.myContainerView.topAnchor.constraint(equalTo: owner.scrollView.contentLayoutGuide.topAnchor)
        }
        
        pgvcTop.isActive = true
    }
    

    func makeScrollViewContentConstraints(for orientation: UIDeviceOrientation) {
        guard let owner = self.owner else { return }
        
        if let topbarView = owner.topbarView {
            self.scrollViewTopContentGuide = owner.scrollView.contentLayoutGuide.topAnchor.constraint(
                equalTo: orientation.isPortrait ?
                topbarView.view.safeAreaLayoutGuide.topAnchor :
                    owner.myContainerView.safeAreaLayoutGuide.topAnchor
            )
        } else {
            self.scrollViewTopContentGuide = owner.scrollView.contentLayoutGuide.topAnchor.constraint(equalTo: owner.myContainerView.safeAreaLayoutGuide.topAnchor)
        }
        
        self.scrollViewTopContentGuide.isActive = true

        owner.scrollView.contentLayoutGuide.leftAnchor.constraint(equalTo: owner.scrollView.frameLayoutGuide.leftAnchor).isActive = true
        owner.scrollView.contentLayoutGuide.rightAnchor.constraint(equalTo: owner.scrollView.frameLayoutGuide.rightAnchor).isActive = true
    }
    
    func updatePageWrapperConstraintsForTransition(to orientation: UIDeviceOrientation, sizeAfterTransition: CGSize) {
        guard let owner = self.owner else { return }
        
        self.pgvcTop.isActive = false
        
        if sizeAfterTransition.width > sizeAfterTransition.height || owner.topbarView == nil {
            self.pgvcTop = owner.myContainerView.topAnchor.constraint(equalTo: owner.scrollView.contentLayoutGuide.topAnchor)
        } else {
            // portrait and topbar not nil
            if let topbarView = owner.topbarView { // always true, just safely unwrapping optional
                self.pgvcTop = owner.myContainerView.topAnchor.constraint(equalTo: topbarView.view.bottomAnchor)
            }
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
    
    func updateScrollViewContentConstraintsForTransition(to orientation: UIDeviceOrientation, sizeAfterTransition: CGSize) {
        guard let owner = self.owner else { return }
        
        self.scrollViewTopContentGuide.isActive = false
        if orientation.isPortrait && owner.topbarView != nil {
            if let topbarView = owner.topbarView {
                self.scrollViewTopContentGuide = owner.scrollView.contentLayoutGuide.topAnchor.constraint(equalTo: topbarView.view.safeAreaLayoutGuide.topAnchor)
                
            }
        } else {
            self.scrollViewTopContentGuide = owner.scrollView.contentLayoutGuide.topAnchor.constraint(equalTo: owner.myContainerView.safeAreaLayoutGuide.topAnchor)
        }
        self.scrollViewTopContentGuide.isActive = true
    }
}
