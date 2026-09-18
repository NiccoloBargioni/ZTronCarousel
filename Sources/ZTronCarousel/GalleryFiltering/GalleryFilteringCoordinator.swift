import Foundation
import ZTronObservation
import ZTronCarouselCore
import os

/// What to do when, after a filter change, the currently displayed gallery has no media that
/// satisfies the active filters.
public enum EmptyGalleryFilteringPolicy: Sendable, Equatable {
    /// Keep the gallery selected and let the carousel display its empty-results placeholder.
    case showPlaceholder
    
    /// Ask the topbar to switch to the sibling gallery — at the same depth — whose position is
    /// closest to the current one, among those with at least one matching media; when no such
    /// sibling exists, fall back to the placeholder.
    case redirectToNearestSibling
}

/// Propagates media filters to the galleries level.
///
/// The coordinator participates in the mediator like every other component: it observes the
/// sibling galleries loaded by the DB loader and the topbar selection. Whenever the active filters
/// change (`filtersDidChange()`), or a new sibling batch arrives, it evaluates through a
/// side-effect-free ``GalleryMediaReading`` how many medias of each sibling satisfy the predicates
/// of the attached `MediaFilteringModel`, then:
/// - broadcasts a ``GalleryFilterStateEventMessage`` so that the topbar at the matching depth
///   disables (and desaturates) the routing elements of the galleries with zero matches;
/// - under ``EmptyGalleryFilteringPolicy/redirectToNearestSibling``, broadcasts a
///   ``GalleryRedirectRequestEventMessage`` when the *current* gallery itself has zero matches.
///
/// Per-gallery match counts are cached and invalidated on any filter change or new sibling batch,
/// so each sibling is read from the database at most once per filter configuration.
@MainActor public final class GalleryFilteringCoordinator<Filter: Hashable>: AnyGalleryFilterCoordinator {
    public let id: String = "gallery filter coordinator"
    
    private static var logger: os.Logger {
        .init(subsystem: "ZTronCarousel", category: "GalleryFilteringCoordinator")
    }
    
    private(set) public nonisolated(unsafe) var lastAction: GalleryFilterCoordinatorAction = .ready
    
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
    
    private weak var filteringModel: MediaFilteringModel<Filter>?
    private let reader: any GalleryMediaReading
    public var policy: EmptyGalleryFilteringPolicy
    
    private var siblings: [ZTronGalleryDescriptor] = []
    private var siblingsDepth: Int = 0
    private var currentGallery: String? = nil
    private var matchCountsCache: [String: Int] = [:]
    
    /// - Parameters:
    ///   - reader: The side-effect-free media source used to probe sibling galleries. Typically the
    ///     page's own `DBCarouselLoader`, which conforms retroactively.
    ///   - model: The same filtering model that drives the carousel, so galleries and medias are
    ///     evaluated with identical predicates and strategy. Held weakly (the carousel owns it).
    ///   - policy: The behavior when the current gallery runs out of matching medias.
    public init(
        reader: any GalleryMediaReading,
        model: MediaFilteringModel<Filter>,
        policy: EmptyGalleryFilteringPolicy = .showPlaceholder
    ) {
        self.reader = reader
        self.filteringModel = model
        self.policy = policy
    }
    
    /// Builds the interactions manager that wires this coordinator to the mediator. Install it via
    /// `setDelegate(_:)`; registration happens automatically.
    public func makeInteractionsManager(mediator: MSAMediator) -> any MSAInteractionsManager {
        return GalleryFilterCoordinatorInteractionsManager(
            owner: self,
            mediator: mediator,
            onGalleriesLoaded: { [weak self] galleries, depth in
                self?.galleriesDidLoad(galleries, depth: depth)
            },
            onLeafGallerySelected: { [weak self] galleryName in
                self?.currentGalleryChanged(galleryName)
            }
        )
    }
    
    // MARK: - Inputs
    
    /// Records the latest batch of sibling galleries (all sharing the same parent) and re-evaluates.
    public func galleriesDidLoad(_ galleries: [ZTronGalleryDescriptor], depth: Int) {
        self.siblings = galleries
        self.siblingsDepth = depth
        self.matchCountsCache.removeAll()
        self.reevaluate()
    }
    
    /// Records the gallery whose medias are currently on display.
    public func currentGalleryChanged(_ galleryName: String?) {
        guard galleryName != self.currentGallery else { return }
        self.currentGallery = galleryName
        self.reevaluate(invalidatingCache: false)
    }
    
    /// Call whenever the set of active filters, their declared effects, or the combining strategy
    /// change. `FilteredCarouselPageFromDB` forwards its fluent filtering interface here.
    public func filtersDidChange() {
        self.reevaluate()
    }
    
    // MARK: - Evaluation
    
    private func reevaluate(invalidatingCache: Bool = true) {
        guard let model = self.filteringModel else { return }
        guard !self.siblings.isEmpty else { return }
        
        if invalidatingCache {
            self.matchCountsCache.removeAll()
        }
        
        guard model.isFiltering else {
            // No active filter: every gallery becomes selectable again.
            self.pushGatingState(disabled: [])
            return
        }
        
        var disabled: Set<String> = []
        
        for gallery in self.siblings {
            if self.matchCount(for: gallery.getName(), using: model) == 0 {
                disabled.insert(gallery.getName())
            }
        }
        
        self.pushGatingState(disabled: disabled)
        
        if self.policy == .redirectToNearestSibling,
           let current = self.currentGallery,
           disabled.contains(current) {
            self.requestRedirect(from: current, disabled: disabled)
        }
    }
    
    private func matchCount(for gallery: String, using model: MediaFilteringModel<Filter>) -> Int {
        if let cached = self.matchCountsCache[gallery] {
            return cached
        }
        
        let descriptors = (try? self.reader.readMediaDescriptorsForGallery(gallery)) ?? []
        let count = descriptors.filter { model.isIncluded($0) }.count
        
        self.matchCountsCache[gallery] = count
        return count
    }
    
    private func pushGatingState(disabled: Set<String>) {
        self.lastAction = .gatingChanged
        self.delegate?.pushNotification(
            eventArgs: GalleryFilterStateEventMessage(
                source: self,
                disabledGalleries: disabled,
                depth: self.siblingsDepth
            )
        )
    }
    
    private func requestRedirect(from current: String, disabled: Set<String>) {
        guard let currentDescriptor = self.siblings.first(where: { $0.getName() == current }) else { return }
        
        // Closest matching sibling by absolute difference of gallery position; on a tie, prefer
        // the forward (higher-position) candidate. Never a disabled gallery, so the topbar's own
        // guard against selecting disabled items lets the switch through.
        let candidate = self.siblings
            .filter { !disabled.contains($0.getName()) }
            .min { lhs, rhs in
                let dl = abs(lhs.getPosition() - currentDescriptor.getPosition())
                let dr = abs(rhs.getPosition() - currentDescriptor.getPosition())
                if dl != dr { return dl < dr }
                return lhs.getPosition() > rhs.getPosition()
            }
        
        guard let candidate = candidate else {
            #if DEBUG
            Self.logger.info("No sibling gallery at depth \(self.siblingsDepth) has medias satisfying the active filters; falling back to the placeholder page.")
            #endif
            return
        }
        
        self.currentGallery = candidate.getName()
        self.lastAction = .redirectRequested
        self.delegate?.pushNotification(
            eventArgs: GalleryRedirectRequestEventMessage(
                source: self,
                gallery: candidate.getName(),
                depth: self.siblingsDepth
            )
        )
    }
    
    // MARK: - Component
    
    nonisolated public func getDelegate() -> (any InteractionsManager)? {
        return self.delegate
    }
    
    nonisolated public func setDelegate(_ interactionsManager: (any InteractionsManager)?) {
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
    
    nonisolated public static func == (lhs: GalleryFilteringCoordinator<Filter>, rhs: GalleryFilteringCoordinator<Filter>) -> Bool {
        return lhs.id == rhs.id
    }
    
    nonisolated public func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }
    
    deinit {
        self.delegate?.detach(or: .ignore)
    }
}

// MARK: - Interactions manager

/// Bridges the mediator to a `GalleryFilteringCoordinator` without depending on its generic
/// parameter: the coordinator hands over `@MainActor` closures at construction (see
/// `GalleryFilteringCoordinator.makeInteractionsManager(mediator:)`).
internal final class GalleryFilterCoordinatorInteractionsManager: MSAInteractionsManager, @unchecked Sendable {
    weak private var owner: (any AnyGalleryFilterCoordinator)? = nil
    weak private var mediator: MSAMediator? = nil
    
    private let onGalleriesLoaded: @MainActor ([ZTronGalleryDescriptor], Int) -> Void
    private let onLeafGallerySelected: @MainActor (String?) -> Void
    
    internal init(
        owner: any AnyGalleryFilterCoordinator,
        mediator: MSAMediator,
        onGalleriesLoaded: @escaping @MainActor ([ZTronGalleryDescriptor], Int) -> Void,
        onLeafGallerySelected: @escaping @MainActor (String?) -> Void
    ) {
        self.owner = owner
        self.mediator = mediator
        self.onGalleriesLoaded = onGalleriesLoaded
        self.onLeafGallerySelected = onLeafGallerySelected
    }
    
    func peerDiscovered(eventArgs: BroadcastArgs) {
        guard let owner = self.owner else { return }
        
        if let dbLoader = (eventArgs.getSource() as? (any AnyDBLoader)) {
            self.mediator?.signalInterest(owner, to: dbLoader, or: .ignore)
        } else {
            if let topbarModel = (eventArgs.getSource() as? (any AnyTopbarModel)) {
                self.mediator?.signalInterest(owner, to: topbarModel, or: .ignore)
            }
        }
    }
    
    func peerDidAttach(eventArgs: BroadcastArgs) {
        
    }
    
    func notify(args: BroadcastArgs) {
        guard self.owner != nil else { return }
        
        if let dbLoader = (args.getSource() as? (any AnyDBLoader)) {
            if dbLoader.lastAction == .galleriesLoaded {
                if let galleriesMessage = ((args as? MSAArgs)?.getPayload() as? GalleriesLoadedEventMessage) {
                    let galleries = galleriesMessage.galleries
                    let depth = dbLoader.getCurrentDepth()
                    let handler = self.onGalleriesLoaded
                    
                    Task(priority: .userInitiated) { @MainActor in
                        handler(galleries, depth)
                    }
                }
            }
        } else {
            if let topbarModel = (args.getSource() as? (any AnyTopbarModel)) {
                if topbarModel.lastAction == .selectedItemChanged && topbarModel.selectedItemStrategy == .leaf {
                    let selectedItemName = topbarModel.getSelectedItemName()
                    let handler = self.onLeafGallerySelected
                    
                    Task(priority: .userInitiated) { @MainActor in
                        handler(selectedItemName)
                    }
                }
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
