import ZTronObservation

internal final class TopbarInteractionsManager: MSAInteractionsManager, @unchecked Sendable {
    weak private var owner: (any AnyTopbarModel)? = nil
    weak private var mediator: MSAMediator? = nil
    
    init(owner: (any AnyTopbarModel), mediator: MSAMediator) {
        self.owner = owner
        self.mediator = mediator
    }
    
    func peerDiscovered(eventArgs: ZTronObservation.BroadcastArgs) {
        guard let owner = self.owner else { return }
        
        if let dbLoader = (eventArgs.getSource() as? (any AnyDBLoader)) {
            self.mediator?.signalInterest(owner, to: dbLoader)
        } else {
            if let searchController = (eventArgs.getSource() as? (any AnySearchController)) {
                self.mediator?.signalInterest(owner, to: searchController)
            }
        }
    }
    
    func peerDidAttach(eventArgs: ZTronObservation.BroadcastArgs) {

    }
    
    func notify(args: ZTronObservation.BroadcastArgs) {
        guard let owner = self.owner else { return }
        
        
        if let dbLoader = (args.getSource() as? (any AnyDBLoader)) {
            let newTopbarItems = dbLoader.getGalleries().map({ galleryModel in
                return TopbarItem(icon: galleryModel.getAssetsImageName() ?? "placeHolder", name: galleryModel.getName())
            })
            
            if dbLoader.lastAction == .galleriesLoaded {
                Task(priority: .userInitiated) { @MainActor in
                    owner.replaceItems(with: newTopbarItems)
                    owner.setIsRedacted(to: false)
                }
            }
        } else {
            if let searchController = args.getSource() as? any AnySearchController {
                if searchController.lastAction == .imageSelected {
                    if let imageSelectedMessage = (args as? MSAArgs)?.getPayload() as? ImageSelectedFromSearchEventMessage {
                        if let leafGallery = imageSelectedMessage.getGalleryPath().last {
                            owner.switchTo(itemNamed: leafGallery.getName())
                        }
                    }
                }
            }
        }
    }
    
    func willCheckout(args: ZTronObservation.BroadcastArgs) {
        
    }
    
    func getOwner() -> (any ZTronObservation.Component)? {
        return self.owner
    }
    
    func getMediator() -> (any ZTronObservation.Mediator)? {
        return self.mediator
    }
}
