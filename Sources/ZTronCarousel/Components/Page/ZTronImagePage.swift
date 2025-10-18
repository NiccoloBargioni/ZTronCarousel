import UIKit
import SwiftSVG
import SkeletonView

import ZTronObservation
import ZTronCarouselCore

open class ZTronImagePage: BasicImagePage, Component, AnyPage {
    public let id: String
    nonisolated(unsafe) private var delegate: (any MSAInteractionsManager)? = nil
    private(set) public var imageName: String
    private(set) public var lastAction: PageAction = .browsing
    
    private var placeables: [any PlaceableView] = []
    private var placeablesConstraints: [ZTronImagePage.PlaceableConstraints] = []
    private var overlays: [UIView] = []
    
    private let mediator: MSAMediator?

    private var animation: (any VariantAnimation)? = nil
    
    private var currentWidth: CGFloat = .zero
        
    init(
        imageDescriptor: ImageWithPlaceablesAndOverlaysDescriptor,
        placeablesFactory: (any ZTronPlaceableFactory)? = nil,
        overlaysFactory: (any ZTronOverlayFactory)? = nil,
        mediator: MSAMediator? = nil
    ) {
        self.imageName = imageDescriptor.getAssetName()
        self.id = imageDescriptor.getAssetName()
        self.mediator = mediator
        
        let placeableDescriptors = imageDescriptor.getPlaceableDescriptors()
        let placeablesFactory = placeablesFactory ?? ZTronBasicPlaceableFactory(mediator: mediator)
        
        let overlaysDescriptors = imageDescriptor.getOverlaysDescriptors()
        let overlaysFactory = overlaysFactory ?? EmptyOverlayFactory()
        
        super.init(imageDescriptor: imageDescriptor)
        
        self.view.isSkeletonable = false
                
        placeableDescriptors.forEach { descriptor in
            placeablesFactory.make(placeable: descriptor).forEach { thisPlaceable in
                self.placeables.append(thisPlaceable)
                self.placeablesConstraints.append(Self.PlaceableConstraints())
                thisPlaceable.translatesAutoresizingMaskIntoConstraints = false
            }
        }
        
        self.placeables.forEach {
            self.imageView.addSubview($0)
        }
        
        overlaysDescriptors.forEach {
            overlaysFactory.make(overlay: $0).forEach {
                self.overlays.append($0)
            }
        }
        
        super.scrollView.backgroundColor = .clear
    }
    
    required public init?(coder: NSCoder) {
        fatalError("Cannot init from storyboard")
    }
        
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        self.overlays.forEach {
            self.view.addSubview($0)
            
            $0.layer.zPosition = 1
            $0.subviews.forEach { subview in
                subview.layer.zPosition = 1
            }
            
            $0.snp.makeConstraints { make in
                make.top.right.bottom.left.equalToSuperview()
            }
            
            $0.setNeedsLayout()
        }
    }
    
    @MainActor public final func attachAnimation(_ animationDescriptor: ImageVariantDescriptor, forward: Bool = true) {
        guard self.lastAction != .animationEnded else { fatalError() }
        
        let boundingFrame = animationDescriptor.getBoundingFrame()
        
        guard boundingFrame.size.width <= 0.95 && boundingFrame.size.height <= 0.95 else {
            self.lastAction = .animationEnded
            self.pushNotification()
            return
        }
        
        let animation: any VariantAnimation = forward ? UIVariantChangedForwardAnimation(
            target: animationDescriptor.getSlave(),
            bundle: .main,
            initialNormalizedAABB: animationDescriptor.getBoundingFrame()
        ) { _ in
            self.lastAction = .animationEnded
            self.delegate?.pushNotification(eventArgs: BroadcastArgs(source: self), limitToNeighbours: true)
        } : UIVariantChangeGoBackAnimation(
            master: animationDescriptor.getMaster(),
            slave: animationDescriptor.getSlave(),
            bundle: .main,
            initialNormalizedAABB: animationDescriptor.getBoundingFrame()
        ) { _ in
            self.lastAction = .animationEnded
            self.delegate?.pushNotification(eventArgs: BroadcastArgs(source: self), limitToNeighbours: true)
        }
        
        
        self.imageView.addSubview(animation)
        
        animation.snp.makeConstraints { make in
            make.top.right.bottom.left.equalTo(animation.superview!.safeAreaLayoutGuide)
        }
                    
        self.animation = animation
        self.lastAction = .animationStarted

        self.view.layoutIfNeeded()
        animation.start()
        self.delegate?.pushNotification(eventArgs: BroadcastArgs(source: self), limitToNeighbours: true)
    }
        
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
                
        self.placeables.forEach { thePlaceable in
            thePlaceable.viewDidAppear()
        }
        
        if let mediator = self.mediator {
            self.setDelegate(ImagePageInteractionsManager(owner: self, mediator: mediator))
        }
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        self.placeables.forEach { thePlaceable in
            thePlaceable.viewWillDisappear()
        }
        
        self.setDelegate(nil)
    }
     
    
    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if self.currentWidth != self.view.bounds.width {
            self.currentWidth = self.view.bounds.width
            
            if #unavailable(iOS 16) {
                DispatchQueue.main.async {
                    self.makePlaceablesConstraintsIfNeeded()

                    self.overlays.forEach {
                        self.view.bringSubviewToFront($0)
                    }
                }
            } else {
                self.makePlaceablesConstraintsIfNeeded()

                self.overlays.forEach {
                    self.view.bringSubviewToFront($0)
                }
            }
        }
    }
        
    
    private final func makePlaceablesConstraintsIfNeeded() {
        let sizeThatFits = CGSize.sizeThatFits(containerSize: super.scrollView.bounds.size, containedAR: 16.0/9.0)
        
        self.placeables.enumerated().forEach { i, thePlaceable in
            let newOrigin = thePlaceable.getOrigin(for: sizeThatFits)
            let newSize = thePlaceable.getSize(for: sizeThatFits)
            
            self.placeablesConstraints[i].top?.isActive = false
            self.placeablesConstraints[i].top = thePlaceable.topAnchor.constraint(
                equalTo: thePlaceable.superview!.safeAreaLayoutGuide.topAnchor,
                constant: newOrigin.y
            )
            self.placeablesConstraints[i].top?.isActive = true
            
            self.placeablesConstraints[i].left?.isActive = false
            self.placeablesConstraints[i].left = thePlaceable.leftAnchor.constraint(
                equalTo: thePlaceable.superview!.safeAreaLayoutGuide.leftAnchor,
                constant: newOrigin.x
            )
            self.placeablesConstraints[i].left?.isActive = true
            
            self.placeablesConstraints[i].width?.isActive = false
            self.placeablesConstraints[i].width = thePlaceable.widthAnchor.constraint(
                equalToConstant: newSize.width
            )
            self.placeablesConstraints[i].width?.isActive = true
            
            self.placeablesConstraints[i].height?.isActive = false
            self.placeablesConstraints[i].height = thePlaceable.heightAnchor.constraint(equalToConstant: newSize.height)
            self.placeablesConstraints[i].height?.isActive = true
                        
            thePlaceable.resize(for: sizeThatFits)
        }
        
        self.view.layoutIfNeeded()
    }
    
    public func scrollViewDidZoom(_ scrollView: UIScrollView) {
        self.placeables.forEach {
            $0.updateForZoom(scrollView)
        }
    }
    
    nonisolated public final func getDelegate() -> (any ZTronObservation.InteractionsManager)? {
        return self.delegate
    }
    
    nonisolated public final func setDelegate(_ interactionsManager: (any ZTronObservation.InteractionsManager)?) {
        guard let interactionsManager = interactionsManager as? MSAInteractionsManager else {
            if interactionsManager == nil {
                if let delegate = self.delegate {
                    delegate.detach(or: .ignore)
                }
            } else {
                fatalError("Provide an interaction manager of type \(String(describing: MSAInteractionsManager.self))")
            }
            
            self.delegate = nil
            
            return
        }
                
        if let delegate = self.delegate {
            delegate.detach(or: .ignore)
        }
        
        self.delegate = interactionsManager
        
        interactionsManager.setup(or: .replace)
    }
    
    
    override open func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate { _ in

        } completion: { _ in
            self.animation?.viewWillTransitionTo(size: self.view.bounds.size, with: coordinator)
        }
    }
    
    deinit {
        self.delegate?.detach(or: .ignore)
    }
    
    private struct PlaceableConstraints {
        fileprivate var top: NSLayoutConstraint?
        fileprivate var left: NSLayoutConstraint?
        fileprivate var width: NSLayoutConstraint?
        fileprivate var height: NSLayoutConstraint?
    }
}
