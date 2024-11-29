import ZTronObservation
import ZTronCarouselCore

public final class CaptionViewInteractionsManager: MSAInteractionsManager, @unchecked Sendable {
    weak private var captionView: (any AnyCaptionView)?
    weak private var mediator: MSAMediator?
    
    public init(captionView: (any AnyCaptionView), mediator: MSAMediator) {
        self.captionView = captionView
        self.mediator = mediator
    }
    
    
    public func peerDiscovered(eventArgs: ZTronObservation.BroadcastArgs) {
        guard let owner = self.captionView else { return }
        
        if let carousel = eventArgs.getSource() as? CarouselComponent {
            self.mediator?.signalInterest(owner, to: carousel)
        }
    }
    
    public func peerDidAttach(eventArgs: ZTronObservation.BroadcastArgs) {
        
    }
    
    public func notify(args: ZTronObservation.BroadcastArgs) {
        guard let owner = self.captionView else { return }
        
        if let carousel = args.getSource() as? CarouselComponent {
            Task(priority: .userInitiated) { @MainActor in
                if let currentMediaDescriptor = carousel.currentMediaDescriptor as? ZTronCarouselImageDescriptor {
                    owner.setText(body: currentMediaDescriptor.getCaption())
                }
            }
        }
    }
    
    public func willCheckout(args: ZTronObservation.BroadcastArgs) {
        
    }
    
    public func getOwner() -> (any ZTronObservation.Component)? {
        return self.captionView
    }
    
    public func getMediator() -> (any ZTronObservation.Mediator)? {
        return self.mediator
    }

    
    
}
