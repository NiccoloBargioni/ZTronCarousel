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
