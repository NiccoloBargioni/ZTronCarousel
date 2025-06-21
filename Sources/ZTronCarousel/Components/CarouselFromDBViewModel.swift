import Foundation
import ZTronObservation

public final class CarouselFromDBViewModel: AnyViewModel, @unchecked Sendable {
    public let id: String = "viewModel"
    weak public var viewModel: CarouselPageFromDB?
    @InteractionsManaging(setupOr: .ignore, detachOr: .fail) var delegate: (any MSAInteractionsManager)? = nil
    
    
    public func getDelegate() -> (any ZTronObservation.InteractionsManager)? {
        return self.delegate
    }
    
    public func setDelegate(_ interactionsManager: (any ZTronObservation.InteractionsManager)?) {
        guard let interactionsManager = interactionsManager as? MSAInteractionsManager else {
            if interactionsManager == nil {
                self.delegate = nil
                return
            } else {
                fatalError("Expected delegate of type \(String(describing: MSAInteractionsManager.self)) in \(#function)@\(#file)")
            }
        }
        
        self.delegate = interactionsManager
    }
    
    public static func == (lhs: CarouselFromDBViewModel, rhs: CarouselFromDBViewModel) -> Bool {
        return lhs.id == rhs.id && lhs.viewModel === rhs.viewModel
    }
    
    @MainActor public func hide() {
        guard let owner = self.viewModel else { return }
        
        owner.view.subviews.forEach { $0.isHidden = true }
    }
    
    @MainActor public func show() {
        guard let owner = self.viewModel else { return }
        
        owner.view.subviews.forEach {
            $0.isHidden = false
        }
    }
    
    @MainActor public func switchPage(_ to: Int) {
        guard let owner = self.viewModel else { return }
        
        owner.thePageVC.turnPage(to: to)
    }
    
    public func loadImages() throws {
        guard let owner = self.viewModel else { return }
        Task(priority: .userInitiated) {
            try owner.reloadImages()
        }
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }
    
    @MainActor public func toggleCaption() {
        guard let owner = self.viewModel else { return }
        guard owner.captionView.displayStrategy == .overlay else { return }
        
        owner.toggleCaptionOverlay()
    }

    
    deinit {
        self.delegate?.detach()
    }
}
