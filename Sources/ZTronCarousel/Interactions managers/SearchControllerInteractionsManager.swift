import ZTronObservation

public final class SearchControllerInteractionsManager: MSAInteractionsManager, @unchecked Sendable {
    weak private var searchController: (any AnySearchController)?
    weak private var mediator: MSAMediator?
    
    public init(owner: any AnySearchController, mediator: MSAMediator) {
        self.searchController = owner
        self.mediator = mediator
    }
    
    public func peerDiscovered(eventArgs: ZTronObservation.BroadcastArgs) {
        guard let owner = self.searchController else { return }
        
        if let dbLoader = eventArgs.getSource() as? any AnyDBLoader {
            self.mediator?.signalInterest(owner, to: dbLoader)
        }
    }
    
    public func peerDidAttach(eventArgs: ZTronObservation.BroadcastArgs) {
        
    }
    
    public func notify(args: ZTronObservation.BroadcastArgs) {
        guard let owner = self.searchController else { return }

        if let dbLoader = args.getSource() as? any AnyDBLoader {
            if let galleriesLoadedMessage = ((args as? MSAArgs)?.getPayload() as? GalleriesGraphLoadedEventMessage) {
                if dbLoader.lastAction == .loadedGalleriesGraph {
                    print("SEARCH CONTROLLER: GALLERIES LOADED")
                    owner.galleriesLoaded(galleriesLoadedMessage.galleries)
                }
            } else {
                if dbLoader.lastAction == .imagesLoadedForSearch {
                    print("SEARCH CONTROLLER: IMAGES LOADED")
                    if let imagesLoadedMessage = ((args as? MSAArgs)?.getPayload() as? ImagesLoadedForSearchEventMessage) {
                        owner.imagesLoaded(imagesLoadedMessage.images.map {SearchableImage(from: $0) } )
                    }
                }
            }
        }
    }
    
    public func willCheckout(args: ZTronObservation.BroadcastArgs) {
        
    }
    
    public func getOwner() -> (any ZTronObservation.Component)? {
        return self.searchController
    }
    
    public func getMediator() -> (any ZTronObservation.Mediator)? {
        return self.mediator
    }
}
