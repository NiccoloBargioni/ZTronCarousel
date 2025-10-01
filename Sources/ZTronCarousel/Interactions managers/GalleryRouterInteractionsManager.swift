import Foundation
import ZTronObservation
import ZTronCarouselCore

open class GalleryRouterInteractionsManager: MSAInteractionsManager, @unchecked Sendable {
    private(set) open var owner: (any AnyGalleryRouter)?
    private(set) public var mediator: MSAMediator?
    
    open var acknowledgedTopbar: Bool = false
    
    public init(owner: (any AnyGalleryRouter), mediator: MSAMediator) {
        self.owner = owner
        self.mediator = mediator
    }
    
    public func peerDiscovered(eventArgs: ZTronObservation.BroadcastArgs) {
        guard let owner = self.owner else { return }
        
        if let dbLoader = eventArgs.getSource() as? any AnyDBLoader {
            self.mediator?.signalInterest(owner, to: dbLoader)
        }
    }
    
    public func peerDidAttach(eventArgs: ZTronObservation.BroadcastArgs) {
        
    }
    
    public func notify(args: ZTronObservation.BroadcastArgs) {
        guard let owner = self.owner else { return }
        
        if let dbLoader = args.getSource() as? (any AnyDBLoader) {
            if dbLoader.lastAction == .imagesLoaded {
                if let mediasChangedArgs = ((args as? MSAArgs)?.getPayload() as? MediasLoadedEventMessage) {
                    owner.onImagesChanged(mediasChangedArgs.medias)
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
