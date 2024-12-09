import Foundation
import ZTronObservation
import ZTronCarouselCore

public protocol ZTronInteractionsManagersFactory: Sendable, AnyObject {
    func makeDBLoaderInteractionsManager(owner: any AnyDBLoader, mediator: MSAMediator) -> any MSAInteractionsManager
    func makeBottomBarInteractionsManager(owner: any AnyBottomBar, mediator: MSAMediator) -> any MSAInteractionsManager
    func makeCaptionViewInteractionsManager(owner: any AnyCaptionView, mediator: MSAMediator) -> any MSAInteractionsManager
    func makeCarouselInteractionsManager(owner: any AnyViewModel, mediator: MSAMediator) -> any MSAInteractionsManager
    func makeCarouselComponentInteractionsManager(owner: CarouselComponent, mediator: MSAMediator) -> any MSAInteractionsManager
    func makeSearchControllerInteractionsManager(owner: any AnySearchController, mediator: MSAMediator) -> any MSAInteractionsManager
}
