import Foundation
import ZTronObservation
import ZTronCarouselCore

public final class CarouselInteractionsManger: MSAInteractionsManager, @unchecked Sendable {
    weak private var owner: CarouselComponent?
    weak private var mediator: MSAMediator?
    
    private var acknowledgedTopbar: Bool = false
    
    public init(owner: CarouselComponent, mediator: MSAMediator) {
        self.owner = owner
        self.mediator = mediator
    }
    
    public func peerDiscovered(eventArgs: ZTronObservation.BroadcastArgs) {
        guard let owner = self.owner else { return }
        
        if let bottomBar = eventArgs.getSource() as? (any AnyBottomBar) {
            self.mediator?.signalInterest(owner, to: bottomBar, or: .ignore)
        } else {
            if let colorPicker = eventArgs.getSource() as? PlaceableColorPicker {
                self.mediator?.signalInterest(owner, to: colorPicker, or: .ignore)
            } else {
                if let dbLoader = eventArgs.getSource() as? (any AnyDBLoader) {
                    self.mediator?.signalInterest(owner, to: dbLoader, or: .ignore)
                } else {
                    if let page = eventArgs.getSource() as? (any AnyPage) {
                        self.mediator?.signalInterest(owner, to: page, or: .ignore)
                    } else {
                        if let topbar = eventArgs.getSource() as? (any AnyTopbarModel) {
                            self.mediator?.signalInterest(owner, to: topbar)
                            self.acknowledgedTopbar = true
                        } else {
                            if let router = eventArgs.getSource() as? (any AnyGalleryRouter) {
                                self.mediator?.signalInterest(owner, to: router)
                            }
                        }
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
                    } else {
                        if let router = args.getSource() as? (any AnyGalleryRouter) {
                            Task(priority: .userInitiated) { @MainActor in
                                self.handleGalleryRouterNotification(router)
                            }
                        }
                    }
                }
            }
        }
    }
    
    public func willCheckout(args: ZTronObservation.BroadcastArgs) {
        if let _ = args.getSource() as? any AnyTopbarModel {
            self.acknowledgedTopbar = false
        }
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
        } else {
            if dbLoader.lastAction == .galleriesLoaded && !self.acknowledgedTopbar {
                Task(priority: .userInitiated) { @MainActor in
                    if owner.lastAction == .ready {
                        self.pushNotification(eventArgs: .init(source: owner), limitToNeighbours: true)
                    }
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
    
    @MainActor private final func handleGalleryRouterNotification(_ router: any AnyGalleryRouter) {
        guard let owner = self.owner else { return }
        guard owner.numberOfPages > 0 else { return }
        
        switch router.lastAction {
            case .next:
                owner.turnPage(to: (owner.currentPage + 1) % owner.numberOfPages)
                
            case .previous:
                owner.turnPage(to: (owner.currentPage - 1 + owner.numberOfPages) % owner.numberOfPages)
                
            case .skip(let requestedPage):
                if requestedPage >= 0 && requestedPage < owner.numberOfPages {
                    owner.turnPage(to: requestedPage)
                }
                
            default:
                break
        }
        
    }
}
