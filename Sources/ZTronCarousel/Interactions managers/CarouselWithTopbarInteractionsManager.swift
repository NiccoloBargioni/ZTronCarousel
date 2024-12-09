import ZTronObservation
import ZTronCarouselCore

public final class CarouselWithTopbarInteractionsManager: MSAInteractionsManager, @unchecked Sendable {
    weak private var owner: (any AnyViewModel)?
    weak private var mediator: MSAMediator?
    
    private var requestedImageIndex: Int = 0
    
    public init(owner: (any AnyViewModel)? = nil, mediator: MSAMediator? = nil) {
        self.owner = owner
        self.mediator = mediator
    }
    
    public func peerDiscovered(eventArgs: ZTronObservation.BroadcastArgs) {
        guard let owner = self.owner else { return }
        
        if let loader = (eventArgs.getSource() as? (any AnyDBLoader)) {
            self.mediator?.signalInterest(owner, to: loader)
        } else {
            if let searchController = (eventArgs.getSource() as? (any AnySearchController)) {
                self.mediator?.signalInterest(owner, to: searchController)
            }
        }
    }
    
    public func peerDidAttach(eventArgs: ZTronObservation.BroadcastArgs) {

    }
    
    public func notify(args: ZTronObservation.BroadcastArgs) {
        guard let owner = self.owner else { return }
                
        if let loader = (args.getSource() as? (any AnyDBLoader)) {
            if loader.lastAction == .imagesLoaded {
                let newImages = loader.getImages()
                
                Task(priority: .userInitiated) { @MainActor in
                    owner.viewModel?.thePageVC.replaceAllMedias(with: newImages, present: self.requestedImageIndex)
                    self.requestedImageIndex = 0
                    
                    owner.show()
                }
            }
        } else {
            if let searchController = (args.getSource() as? (any AnySearchController)) {
                if searchController.lastAction == .loadAllMasterImages {
                    Task(priority: .userInitiated) { @MainActor in
                        owner.hide()
                    }
                } else {
                    if searchController.lastAction == .imageSelected {
                        if let imageSelectedMessage = ((args as? MSAArgs)?.getPayload() as? ImageSelectedFromSearchEventMessage) {
                            self.requestedImageIndex = imageSelectedMessage.getSelectedImage().getPosition()
                        }
                    } else {
                        if searchController.lastAction == .cancelled {
                            Task(priority: .userInitiated) { @MainActor in
                                owner.show()
                            }
                        }
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
