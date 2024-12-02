import Foundation
import ZTronObservation
import ZTronCarouselCore

public final class CarouselInteractionsManger: MSAInteractionsManager, @unchecked Sendable {
    weak private var owner: CarouselComponent?
    weak private var mediator: MSAMediator?
    
    public init(owner: CarouselComponent, mediator: MSAMediator) {
        self.owner = owner
        self.mediator = mediator
    }
    
    public func peerDiscovered(eventArgs: ZTronObservation.BroadcastArgs) {
        guard let owner = self.owner else { return }
        
        if let bottomBar = eventArgs.getSource() as? (any AnyBottomBar) {
            self.mediator?.signalInterest(owner, to: bottomBar)
        } else {
            if let colorPicker = eventArgs.getSource() as? PlaceableColorPicker {
                self.mediator?.signalInterest(owner, to: colorPicker)
            } else {
                if let dbLoader = eventArgs.getSource() as? (any AnyDBLoader) {
                    self.mediator?.signalInterest(owner, to: dbLoader)
                } else {
                    if let page = eventArgs.getSource() as? (any AnyPage) {
                        self.mediator?.signalInterest(owner, to: page)
                    }
                }
            }
        }
    }
    
    public func peerDidAttach(eventArgs: ZTronObservation.BroadcastArgs) {
        
    }
    
    public func notify(args: ZTronObservation.BroadcastArgs) {
        guard let _ = self.owner else { return }
        
        if let bottomBar = args.getSource() as? (any AnyBottomBar) {
            self.handleBottomBarNotification(bottomBar)
        } else {
            if let colorPicker = args.getSource() as? PlaceableColorPicker {
                self.handleColorPickerNotification(colorPicker)
            } else {
                if let dbLoader = args.getSource() as? (any AnyDBLoader) {
                    self.handleDBLoaderNotification(dbLoader, args: args)
                } else {
                    if let page = args.getSource() as? (any AnyPage) {
                        self.handlePageNotification(page)
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
    
    private func handleColorPickerNotification(_ colorPicker: PlaceableColorPicker) {
        guard let owner = owner else { return }
        Task(priority: .userInitiated) { @MainActor in
            if let currentMediaDescriptor = owner.currentMediaDescriptor as? ZTronCarouselImageDescriptor {
                if let hexString = colorPicker.getSelectedColor().hexString {
                    owner.replaceMedia(
                        with:
                            currentMediaDescriptor
                                .getMutableCopy()
                                .replacingOutline { outlineDescriptor in
                                    outlineDescriptor.withColorHex(hexString)
                                }
                                .replacingBoundingCircle{ boundingCircleDescriptor in
                                    boundingCircleDescriptor.withColorHex(hexString)
                                }
                                .getImmutableCopy()
                        ,
                        at: owner.currentPage,
                        shouldReplaceViewController: false
                    )
                }
            }
        }
    }
    
    private func handleBottomBarNotification(_ bottomBar: any AnyBottomBar) {
        guard let owner = self.owner else { return }
        
        Task(priority: .userInitiated) { @MainActor in
            switch bottomBar.lastAction {
                case .toggleOutline:
                    if let currentMediaDescriptor = owner.currentMediaDescriptor as? ZTronCarouselImageDescriptor {
                        owner.replaceMedia(
                            with: currentMediaDescriptor.getMutableCopy().replacingOutline { outlineDraft in
                                outlineDraft.togglingActive()
                            }.getImmutableCopy(),
                            at: owner.currentPage,
                            shouldReplaceViewController: false
                        )
                    }
                    
                case .toggleBoundingCircle:
                    if let currentMediaDescriptor = owner.currentMediaDescriptor as? ZTronCarouselImageDescriptor {
                        owner.replaceMedia(
                            with: currentMediaDescriptor.getMutableCopy().replacingBoundingCircle { outlineDraft in
                                outlineDraft.togglingActive()
                            }.getImmutableCopy(),
                            at: owner.currentPage,
                            shouldReplaceViewController: false
                        )
                    }
                    
                default:
                    break
            }
        }
    }
    
    private func handleDBLoaderNotification(_ dbLoader: any AnyDBLoader, args: BroadcastArgs) {
        guard let owner = owner else { return }
        
        if dbLoader.lastAction == .variantLoadedForward || dbLoader.lastAction == .variantLoadedBackward {
            if let variantChangedEvent = ((args as? MSAArgs)?.getPayload() as? VariantLoadedEventMessage) {
                Task { @MainActor in
                    owner.replaceMedia(
                        with: variantChangedEvent.getImageDescriptor(),
                        at: owner.currentPage,
                        shouldReplaceViewController: false
                    )
                }
            }
        }
    }
    
    private func handlePageNotification(_ page: any AnyPage) {
        guard let owner = self.owner else { return }
        
        Task(priority: .userInitiated) { @MainActor in
            if page.lastAction == .animationStarted {
                owner.view.isUserInteractionEnabled = false
            } else {
                if page.lastAction == .animationEnded {
                    if let currentMediaDescriptor = owner.currentMediaDescriptor {
                        owner.replaceMedia(with: currentMediaDescriptor, at: owner.currentPage)
                        owner.view.isUserInteractionEnabled = true
                    }
                }
            }
        }
    }
}
