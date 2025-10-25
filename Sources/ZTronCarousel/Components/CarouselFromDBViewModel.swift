import Foundation
import ZTronObservation

public final class CarouselFromDBViewModel: AnyViewModel, @unchecked Sendable {
    public let id: String = "viewModel"
    private(set) public var lastAction: CarouselFromDBLastAction = .ready
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
    
    
    public func updateOutlineOriginX(_ x: CGFloat) {
        assert(x >= 0 && x <= 1)
        self.lastAction = .updateOutlineOffsetX(x)
        self.pushNotification()
    }
    
    public func updateOutlineOriginY(_ y: CGFloat) {
        assert(y >= 0 && y <= 1)
        self.lastAction = .updateOutlineOffsetY(y)
        self.pushNotification()
    }
    
    public func updateOutlineWidth(_ width: CGFloat) {
        assert(width >= 0 && width <= 1)
        self.lastAction = .updateSizeWidth(width)
        self.pushNotification()
    }
    
    public func updateOutlineHeight(_ height: CGFloat) {
        assert(height >= 0 && height <= 1)
        self.lastAction = .updateSizeHeight(height)
        self.pushNotification()
    }

}


public enum CarouselFromDBLastAction {
    case ready
    case updateOutlineOffsetX(CGFloat)
    case updateOutlineOffsetY(CGFloat)
    case updateSizeWidth(CGFloat)
    case updateSizeHeight(CGFloat)
}
