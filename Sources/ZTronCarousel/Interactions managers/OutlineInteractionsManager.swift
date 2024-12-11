import Foundation
import ZTronObservation

public final class OutlineInteractionsManager: MSAInteractionsManager, @unchecked Sendable {
    weak private var owner: ZTronSVGView?
    weak private var mediator: MSAMediator?
    
    init(owner: ZTronSVGView, mediator: MSAMediator) {
        self.owner = owner
        self.mediator = mediator
    }
    
    public func peerDiscovered(eventArgs: ZTronObservation.BroadcastArgs) {
        guard let owner = self.owner else { return }
        
        if let colorPicker = eventArgs.getSource() as? PlaceableColorPicker {
            Task(priority: .userInitiated) { @MainActor in
                if colorPicker.parentImage == owner.parentImage {
                    self.mediator?.signalInterest(owner, to: colorPicker, or: .ignore)
                }
            }
        } else {
            Task(priority: .userInitiated) { @MainActor in 
                if let pinnedBottomBar = eventArgs.getSource() as? (any AnyBottomBar) {
                    self.mediator?.signalInterest(owner, to: pinnedBottomBar, or: .ignore)
                }
            }
        }
    }
    
    public func peerDidAttach(eventArgs: ZTronObservation.BroadcastArgs) {
        
    }
    
    public func notify(args: ZTronObservation.BroadcastArgs) {
        guard let owner = self.owner else { return }

        if let colorPicker = args.getSource() as? PlaceableColorPicker {
            Task(priority: .userInitiated) { @MainActor in 
                self.owner?.setStrokeColor(colorPicker.getSelectedColor().cgColor)
            }
        } else {
            if let pinnedBottomBar = args.getSource() as? (any AnyBottomBar) {
                Task(priority: .userInitiated) { @MainActor in
                    if pinnedBottomBar.currentImage == owner.parentImage && pinnedBottomBar.lastAction == .toggleOutline {
                        owner.toggle()
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
