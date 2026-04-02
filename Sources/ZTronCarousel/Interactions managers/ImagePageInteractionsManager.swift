import Foundation
import ZTronObservation

public final class ImagePageInteractionsManager: MSAInteractionsManager, @unchecked Sendable {
    weak private var owner: (any AnyPage)?
    weak private var mediator: MSAMediator?
    
    public init(owner: (any AnyPage), mediator: MSAMediator) {
        self.owner = owner
        self.mediator = mediator
    }
    
    public func peerDiscovered(eventArgs: ZTronObservation.BroadcastArgs) {
        guard let owner = self.owner else { return }
        
        if let dbLoader = (eventArgs.getSource() as? (any AnyDBLoader)) {
            self.mediator?.signalInterest(owner, to: dbLoader, or: .fail)
        }
    }
    
    public func peerDidAttach(eventArgs: ZTronObservation.BroadcastArgs) {
        
    }
    
    public func notify(args: ZTronObservation.BroadcastArgs) {
        guard let owner = self.owner else { return }
        
        if let loader = args.getSource() as? (any AnyDBLoader) {
            let action = loader.lastAction
            
            if action == .variantLoadedForward || action == .variantLoadedBackward {
                if let variantLoadedMessage = ((args as? MSAArgs)?.getPayload() as? VariantLoadedEventMessage) {
                    Task(priority: .userInitiated) { @MainActor in
                        
                        if (
                            action == .variantLoadedForward &&
                            owner.imageName == variantLoadedMessage.getParentVariantDescriptor().getMaster()
                        ) || (
                            action == .variantLoadedBackward && owner.imageName == variantLoadedMessage.getParentVariantDescriptor().getSlave()
                        ) {
                            owner.attachAnimation(
                                variantLoadedMessage.getParentVariantDescriptor(),
                                forward: action == .variantLoadedForward
                            )
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

