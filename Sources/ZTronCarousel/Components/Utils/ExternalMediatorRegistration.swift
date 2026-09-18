import Foundation
import ZTronObservation
import ZTronCarouselCore

/// How long components registered through `CarouselPageFromDB.registerComponents(lifecycle:_:)`
/// stay attached to the page's mediator.
public enum MediatorRegistrationLifecycle: Sendable, Equatable {
    /// Components live as long as the *displayed media*: the setup closure runs when an image
    /// appears, its components are unregistered when that image leaves the screen (swipe, gallery
    /// change, variant change), and the closure runs again for the new one. While the carousel
    /// displays no media (empty dataset, filtered-out gallery), no component is attached.
    case media
    
    /// Components live as long as the *page*: the setup closure runs once, its components persist
    /// across image and gallery changes, and they are unregistered when the page is dismissed or
    /// popped (and, as a safety net, when it is deallocated).
    case page
}

/// One `registerComponents(lifecycle:_:)` call: the lifecycle, the user's setup closure, and the
/// components it currently keeps registered. Reference semantics so the page can tear down and
/// repopulate `live` in place.
internal final class ExternalMediatorRegistration: @unchecked Sendable {
    internal let lifecycle: MediatorRegistrationLifecycle
    internal let setup: @MainActor (MSAMediator) -> [any Component]
    internal var live: [any Component] = []
    
    internal init(
        lifecycle: MediatorRegistrationLifecycle,
        setup: @escaping @MainActor (MSAMediator) -> [any Component]
    ) {
        self.lifecycle = lifecycle
        self.setup = setup
    }
}

/// The component `CarouselPageFromDB` silently adds to its own mediator when at least one
/// `.media`-lifecycle registration exists. Its only job is to observe the carousel and tell the
/// page that the displayed media (possibly) changed, so the page can cycle `.media` registrations.
///
/// It deliberately reads nothing from the carousel inside `notify` — the carousel is `@MainActor`
/// and notifications may arrive off the main actor. Every notification the carousel pushes
/// corresponds to a visual change (`replacedAllMedias`, `pageChanged`, `replacedCurrentMedia`,
/// `replacedCurrentDescriptor`), so the *fact* of a carousel-sourced notification is signal
/// enough; the page inspects the actual state (`currentVisibleMediaDescriptor`) once it's back on
/// the main actor.
internal final class ExternalComponentsLifecycleObserver: Component, @unchecked Sendable {
    internal let id: String = "external components registrar"
    
    nonisolated(unsafe) private var delegate: (any MSAInteractionsManager)? = nil {
        willSet {
            guard let delegate = self.delegate else { return }
            delegate.detach(or: .ignore)
        }
        
        didSet {
            guard let delegate = self.delegate else { return }
            delegate.setup(or: .replace)
        }
    }
    
    private let onCarouselChanged: @MainActor () -> Void
    
    internal init(onCarouselChanged: @escaping @MainActor () -> Void) {
        self.onCarouselChanged = onCarouselChanged
    }
    
    internal func makeInteractionsManager(mediator: MSAMediator) -> any MSAInteractionsManager {
        return ExternalComponentsLifecycleObserverInteractionsManager(
            owner: self,
            mediator: mediator,
            onCarouselChanged: self.onCarouselChanged
        )
    }
    
    // MARK: - Component
    
    internal func getDelegate() -> (any InteractionsManager)? {
        return self.delegate
    }
    
    internal func setDelegate(_ interactionsManager: (any InteractionsManager)?) {
        guard let interactionsManager = interactionsManager as? MSAInteractionsManager else {
            if interactionsManager == nil {
                self.delegate = nil
            } else {
                fatalError("Expected interactions manager of type \(String(describing: MSAInteractionsManager.self)) in \(#function) at \(#file)")
            }
            
            return
        }
        
        self.delegate = interactionsManager
    }
    
    internal static func == (lhs: ExternalComponentsLifecycleObserver, rhs: ExternalComponentsLifecycleObserver) -> Bool {
        return lhs.id == rhs.id
    }
    
    internal func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }
    
    deinit {
        self.delegate?.detach(or: .ignore)
    }
}

internal final class ExternalComponentsLifecycleObserverInteractionsManager: MSAInteractionsManager, @unchecked Sendable {
    weak private var owner: ExternalComponentsLifecycleObserver? = nil
    weak private var mediator: MSAMediator? = nil
    
    private let onCarouselChanged: @MainActor () -> Void
    
    internal init(
        owner: ExternalComponentsLifecycleObserver,
        mediator: MSAMediator,
        onCarouselChanged: @escaping @MainActor () -> Void
    ) {
        self.owner = owner
        self.mediator = mediator
        self.onCarouselChanged = onCarouselChanged
    }
    
    func peerDiscovered(eventArgs: BroadcastArgs) {
        guard let owner = self.owner else { return }
        
        if let carousel = (eventArgs.getSource() as? CarouselComponent) {
            self.mediator?.signalInterest(owner, to: carousel, or: .ignore)
        }
    }
    
    func peerDidAttach(eventArgs: BroadcastArgs) {
        
    }
    
    func notify(args: BroadcastArgs) {
        guard self.owner != nil else { return }
        
        if (args.getSource() as? CarouselComponent) != nil {
            let handler = self.onCarouselChanged
            
            Task(priority: .userInitiated) { @MainActor in
                handler()
            }
        }
    }
    
    func willCheckout(args: BroadcastArgs) {
        
    }
    
    func getOwner() -> (any Component)? {
        return self.owner
    }
    
    func getMediator() -> (any Mediator)? {
        return self.mediator
    }
}
