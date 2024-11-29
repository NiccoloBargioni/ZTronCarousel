// ColorPickerInteractionsManager

import ZTronObservation

internal final class ColorPickerInteractionsManager: MSAInteractionsManager, @unchecked Sendable {
    weak private var owner: PlaceableColorPicker?
    weak private var mediator: MSAMediator?

    init(owner: PlaceableColorPicker?, mediator: MSAMediator?) {
        self.owner = owner
        self.mediator = mediator
    }
    
    func peerDiscovered(eventArgs: ZTronObservation.BroadcastArgs) {
        
    }
    
    func peerDidAttach(eventArgs: ZTronObservation.BroadcastArgs) {
        
    }
    
        
    func notify(args: ZTronObservation.BroadcastArgs) {

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
