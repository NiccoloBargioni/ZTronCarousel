import ZTronObservation
import ZTronCarouselCore

public final class CarouselWithTopbarInteractionsManager: MSAInteractionsManager, @unchecked Sendable {
    weak private var owner: CarouselWithTopbarViewModel?
    weak private var mediator: MSAMediator?
    
    public init(owner: CarouselWithTopbarViewModel? = nil, mediator: MSAMediator? = nil) {
        self.owner = owner
        self.mediator = mediator
    }
    
    
    public func peerDiscovered(eventArgs: ZTronObservation.BroadcastArgs) {
        guard let owner = self.owner else { return }
        
        if let loader = (eventArgs.getSource() as? (any AnyDBLoader)) {
            self.mediator?.signalInterest(owner, to: loader)
        }
    }
    
    public func peerDidAttach(eventArgs: ZTronObservation.BroadcastArgs) {

    }
    
    public func notify(args: ZTronObservation.BroadcastArgs) {
        guard let args = args as? MSAArgs else { return }
        guard let owner = self.owner else { return }
                
        if let loader = (args.getSource() as? (any AnyDBLoader)) {
            if loader.lastAction == .imagesLoaded {
                let newImages = loader.getImages()
                
                Task(priority: .userInitiated) { @MainActor in
                    owner.viewModel?.thePageVC.replaceAllMedias(with: newImages)
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
