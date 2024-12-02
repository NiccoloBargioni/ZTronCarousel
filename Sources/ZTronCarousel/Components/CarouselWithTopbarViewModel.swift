import Foundation
import ZTronObservation

public final class CarouselWithTopbarViewModel: AnyViewModel, @unchecked Sendable {
    public let id: String = "memory charms viewModel"
    weak public var viewModel: CarouselPageWithTopbar?
    private var delegate: (any MSAInteractionsManager)? {
        willSet {
            guard let delegate = self.delegate else { return }
            delegate.detach()
        }
        
        didSet {
            guard let delegate = self.delegate else { return }
            delegate.setup(or: .ignore)
        }
    }
    
    
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
    
    public static func == (lhs: CarouselWithTopbarViewModel, rhs: CarouselWithTopbarViewModel) -> Bool {
        return lhs.id == rhs.id && lhs.viewModel === rhs.viewModel
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }
    
    deinit {
        self.delegate?.detach()
    }
}
