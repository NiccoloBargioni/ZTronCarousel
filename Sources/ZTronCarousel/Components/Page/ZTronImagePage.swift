import UIKit
import SnapKit
import SwiftSVG
import SkeletonView

import ZTronObservation
import ZTronCarouselCore

open class ZTronImagePage: BasicImagePage, Component, AnyPage {
    public let id: String
    nonisolated lazy private var delegate: (any MSAInteractionsManager)? = nil
    private(set) public var imageName: String
    private(set) public var lastAction: PageAction = .browsing
    
    private var placeables: [any PlaceableView] = []
    private var overlays: [UIView] = []
    
    private let mediator: MSAMediator?
    
    private var animation: (any VariantAnimation)? = nil
        
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
        
        if forward {
            let animation = UIVariantChangedForwardAnimation(
                target: animationDescriptor.getSlave(),
                bundle: .main,
                initialNormalizedAABB: animationDescriptor.getBoundingFrame()
            ) { completed in
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
        } else {
            let animation = UIVariantChangeGoBackAnimation(
                master: animationDescriptor.getMaster(),
                slave: animationDescriptor.getSlave(),
                bundle: .main,
                initialNormalizedAABB: animationDescriptor.getBoundingFrame()
            ) { completed in
                self.lastAction = .animationEnded
                self.delegate?.pushNotification(eventArgs: BroadcastArgs(source: self), limitToNeighbours: true)
            }
            
            self.imageView.addSubview(animation)
            
            animation.snp.makeConstraints { make in
                make.top.right.bottom.left.equalTo(animation.superview!.safeAreaLayoutGuide)
            }
            

            self.view.layoutIfNeeded()
            self.animation = animation
            
            self.lastAction = .animationStarted
            animation.start()

            self.delegate?.pushNotification(eventArgs: BroadcastArgs(source: self), limitToNeighbours: true)
        }
    }
        
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
                
        self.placeables.forEach { thePlaceable in
            if let placeable = thePlaceable as? any Component {
                placeable.getDelegate()?.setup(or: .replace)
            }
        }
        
        if let mediator = self.mediator {
            self.setDelegate(ImagePageInteractionsManager(owner: self, mediator: mediator))
        }
    }
    
    override open func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        
        self.placeables.forEach { thePlaceable in
            if let placeable = thePlaceable as? any Component {
                placeable.getDelegate()?.detach(or: .ignore)
            }
        }
        
        self.setDelegate(nil)
    }
     
    
    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
                
        self.makePlaceablesConstraintsIfNeeded()

        self.overlays.forEach {
            self.view.bringSubviewToFront($0)
        }
    }
        
    
    private final func makePlaceablesConstraintsIfNeeded() {
        let sizeThatFits = CGSize.sizeThatFits(containerSize: super.scrollView.bounds.size, containedAR: 16.0/9.0)
        
        self.placeables.forEach { thePlaceable in
            thePlaceable.snp.removeConstraints()
            
            thePlaceable.snp.makeConstraints { make in
                make.left.equalTo(thePlaceable.getOrigin(for: sizeThatFits).x)
                make.top.equalTo(thePlaceable.getOrigin(for: sizeThatFits).y)
                make.width.equalTo(thePlaceable.getSize(for: sizeThatFits).width)
                make.height.equalTo(thePlaceable.getSize(for: sizeThatFits).height)
            }
            
            thePlaceable.resize(for: sizeThatFits)
        }
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
    
}
