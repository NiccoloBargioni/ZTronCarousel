import ZTronObservation
import ZTronCarouselCore

public final class DefaultZTronInteractionsManagerFactory: ZTronInteractionsManagersFactory {    
    public func makeCarouselComponentInteractionsManager(owner: CarouselComponent, mediator: ZTronObservation.MSAMediator) -> any ZTronObservation.MSAInteractionsManager {
        return CarouselInteractionsManger(owner: owner, mediator: mediator)
    }
    
    public func makeDBLoaderInteractionsManager(owner: any AnyDBLoader, mediator: ZTronObservation.MSAMediator) -> any ZTronObservation.MSAInteractionsManager {
        return DBLoaderInteractionsManager(owner: owner, mediator: mediator)
    }
    
    public func makeBottomBarInteractionsManager(owner: any AnyBottomBar, mediator: ZTronObservation.MSAMediator) -> any ZTronObservation.MSAInteractionsManager {
        return PinnedBottomBarInteractionsManager(owner: owner, mediator: mediator)
    }
    
    public func makeCaptionViewInteractionsManager(owner: any AnyCaptionView, mediator: ZTronObservation.MSAMediator) -> any MSAInteractionsManager {
        return CaptionViewInteractionsManager(captionView: owner, mediator: mediator)
    }
    
    public func makeCarouselInteractionsManager(owner: any AnyViewModel, mediator: ZTronObservation.MSAMediator) -> any ZTronObservation.MSAInteractionsManager {
        return CarouselWithTopbarInteractionsManager(owner: owner, mediator: mediator)
    }
}
