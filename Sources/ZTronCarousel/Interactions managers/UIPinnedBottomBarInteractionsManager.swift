import UIKit
import ZTronObservation
import ZTronCarouselCore

public final class PinnedBottomBarInteractionsManager: MSAInteractionsManager, @unchecked Sendable {
    weak private var owner: (any AnyBottomBar)?
    weak private var mediator: MSAMediator?
    private var parentVariant: ImageVariantDescriptor? = nil
    
    private var currentImage: String? = nil {
        didSet {
            guard let currentImage = currentImage else { return }
            guard let owner = self.owner else { return }
            
            owner.setCurrentImage(currentImage)
        }
    }
    
    public init(owner: (any AnyBottomBar), mediator: MSAMediator) {
        self.owner = owner
        self.mediator = mediator
    }
    
    public func peerDiscovered(eventArgs: ZTronObservation.BroadcastArgs) {
        guard let owner = self.owner else { return }
        if let carousel = eventArgs.getSource() as? CarouselComponent {
            self.mediator?.signalInterest(owner, to: carousel, or: .ignore)
        } else {
            if let dbLoader = eventArgs.getSource() as? (any AnyDBLoader) {
                self.mediator?.signalInterest(owner, to: dbLoader, or: .ignore)
            }
        }
    }
    
    public func peerDidAttach(eventArgs: ZTronObservation.BroadcastArgs) {

    }
    
    public func notify(args: ZTronObservation.BroadcastArgs) {
        guard let _ = self.owner else { return }
        
        if let dbLoader = args.getSource() as? (any AnyDBLoader) {
            self.handleDBLoaderNotification(dbLoader, args: args)
        } else {
            if let carousel = args.getSource() as? CarouselComponent {
                if let args = args as? MSAArgs {
                    if args.getFrom() === carousel { // Only handle direct notifications from carousel
                        self.handleCarouselNotification(carousel)
                    }
                }
            }
        }
    }
    
    private final func appendGoBack(currentImageDescriptor: ZTronCarouselImageDescriptor) {
        guard let owner = self.owner else { return }
        if let parentVariant = self.parentVariant {
            if currentImageDescriptor.getMaster() != nil && currentImageDescriptor.getAssetName() == parentVariant.getSlave() {
                Task(priority: .userInitiated) { @MainActor in
                    UIView.animate(withDuration: 0.25) {
                        owner.appendGoBackVariant(icon: parentVariant.getGoBackBottomBarIcon() ?? "arrow.uturn.left")
                    }
                }
            }
        }
    }
    
    private func handleDBLoaderNotification(_ dbLoader: any AnyDBLoader, args: ZTronObservation.BroadcastArgs) {
        guard let owner = self.owner else { return }
        
        if dbLoader.lastAction == .variantLoadedForward || dbLoader.lastAction == .variantLoadedBackward {
            if let variantLoadedMessage = ((args as? MSAArgs)?.getPayload() as? VariantLoadedEventMessage) {
                Task(priority: .userInitiated) { @MainActor in
                    let variantDescriptor = variantLoadedMessage.getParentVariantDescriptor()
                    self.parentVariant = variantDescriptor
                    
                    UIView.animate(withDuration: 0.25) {
                        owner.clearVariantsStack(completion: nil)
                    }
                }
            }
        }
    }
    
    private func handleCarouselNotification(_ carousel: CarouselComponent) {
        guard let owner = self.owner else { return }
        
        Task(priority: .userInitiated) { @MainActor in
            if carousel.lastAction != .replacedCurrentDescriptor {
                if let currentImageDescriptor = carousel.currentMediaDescriptor {
                    self.currentImage = currentImageDescriptor.getAssetName()
                    if let currentImageDescriptor = currentImageDescriptor as? ZTronCarouselImageDescriptor {
                        
                        if let variantsMetadata = currentImageDescriptor.getVariantsDescriptor() {
                            owner.switchVariants(variantsMetadata) { _ in
                                self.appendGoBack(currentImageDescriptor: currentImageDescriptor)
                            }
                        } else {
                            UIView.animate(withDuration: 0.25) {
                                owner.clearVariantsStack { _ in
                                    self.appendGoBack(currentImageDescriptor: currentImageDescriptor)
                                }
                            }
                        }
                    }
                }
            } else {
                guard let currentMediaDescriptor = carousel.currentMediaDescriptor as? ZTronCarouselImageDescriptor else { return }
                guard carousel.lastAction == .replacedCurrentDescriptor else { return }
                
                if let outlineDescriptors = currentMediaDescriptor.getPlaceableDescriptors(for: PlaceableDescriptorType.outline) {
                    if let theOutline = outlineDescriptors.first {
                        owner.setActive(theOutline.getIsActive(), for: .outline)
                    }
                }
                
                if let boundingCircleDescriptors =
                        currentMediaDescriptor.getPlaceableDescriptors(
                            for: PlaceableDescriptorType.boundingCircle
                        )
                {
                    if let theBoundingCircle = boundingCircleDescriptors.first {
                        owner.setActive(theBoundingCircle.getIsActive(), for: .boundingCircle)
                    }
                }
            }
        }
    }
    
    public func willCheckout(args: ZTronObservation.BroadcastArgs) {
        
    }
    
    public func getOwner() -> (any ZTronObservation.Component)? {
        return self.owner
    }
    
    public func getMediator() -> (any ZTronObservation.Mediator)? {
        return self.mediator
    }
}
