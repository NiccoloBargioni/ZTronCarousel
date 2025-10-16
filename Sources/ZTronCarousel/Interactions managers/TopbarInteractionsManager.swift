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
            self.mediator?.signalInterest(owner, to: dbLoader, or: .ignore)
        } else {
            if let searchController = (eventArgs.getSource() as? (any AnySearchController)) {
                self.mediator?.signalInterest(owner, to: searchController, or: .ignore)
            }
        }
    }
    
    func peerDidAttach(eventArgs: ZTronObservation.BroadcastArgs) {

    }
    
    func notify(args: ZTronObservation.BroadcastArgs) {
        guard let owner = self.owner else { return }
        
        
        if let dbLoader = (args.getSource() as? (any AnyDBLoader)) {
            if let args = ((args as? MSAArgs)?.getPayload() as? GalleriesLoadedEventMessage) {
                
                let newTopbarItems = args.galleries.map({ galleryModel in
                    let nestingLevel = galleryModel.getNestingLevel()
                    
                    let isLeaf: Bool = (galleryModel.getImagesCount() ?? 1) > 0 && (galleryModel.getSubgalleriesCount() ?? 0) <= 0
                    
                    return TopbarItem(
                        icon: galleryModel.getAssetsImageName() ?? "placeHolder",
                        name: galleryModel.getName(),
                        strategy: isLeaf ? .leaf : .passthrough(depth: nestingLevel ?? .zero)
                    )
                })
                
                if owner.getDepth() == dbLoader.getCurrentDepth() {
                    if dbLoader.lastAction == .galleriesLoaded {
                        Task(priority: .userInitiated) { @MainActor in
                            owner.replaceItems(with: newTopbarItems)
                            owner.setIsRedacted(to: false)
                        }
                    }
                }
            } else {
                if let args = ((args as? MSAArgs)?.getPayload() as? MediasLoadedEventMessage) {
                    let depthOfImage = args.depth
                    // An image with one topbar is at depth 0, An image under two topbars is at depth 1 and so on
                    if owner.getDepth() > args.depth {
                        owner.hide()
                    } else {
                        owner.show()
                    }
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
