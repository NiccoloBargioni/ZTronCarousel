import Foundation
import ZTronObservation
public final class ZTronInteractionsManagers: Sendable {
    
    public static func defaultTopbarManager(owner: (any AnyTopbarModel), mediator: MSAMediator) -> any MSAInteractionsManager {
        return TopbarInteractionsManager(
            owner: owner,
            mediator: mediator
        )
    }
}
