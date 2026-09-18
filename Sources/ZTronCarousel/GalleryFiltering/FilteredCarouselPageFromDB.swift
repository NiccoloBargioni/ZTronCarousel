import UIKit
import ZTronCarouselCore
import ZTronSerializable
import ZTronObservation
import ZTronTheme

/// A `CarouselPageFromDB` whose carousel supports media filtering, and that propagates the active
/// filters to the galleries level:
/// - routing elements (topbar items) of galleries with **zero** medias matching the filters are
///   disabled and rendered desaturated;
/// - when the *currently displayed* gallery runs out of matching medias, the behavior is governed
///   by ``EmptyGalleryFilteringPolicy``: either the carousel's placeholder page, or an automatic
///   switch to the closest same-depth sibling with at least one match (placeholder as last resort).
///
/// ```swift
/// enum MyFilter: Hashable { case videosOnly, withOutline }
///
/// let page = FilteredCarouselPageFromDB<MyFilter>(
///     foreignKeys: foreignKeys,
///     componentsFactory: CommanderComponentsFactory(),
///     filteringStrategy: .and,
///     emptyGalleryPolicy: .redirectToNearestSibling
/// )
/// .declareEffect(.videosOnly) { $0.type == .video }
/// .declareEffect(.withOutline) { ($0 as? ZTronCarouselImageDescriptor) != nil }
/// .activateFilter(.videosOnly)
/// ```
///
/// Instantiating it as `FilteredCarouselPageFromDB` (no generic argument) infers
/// `Filter == EmptyFilter` and yields a page that behaves exactly like `CarouselPageFromDB`.
@MainActor open class FilteredCarouselPageFromDB<Filter: Hashable>: CarouselPageFromDB {
    /// The same instance as `thePageVC`, retained with its concrete generic type so that the
    /// fluent filtering interface stays fully typed.
    public let filteredCarousel: FilterableCarouselComponent<Filter>
    
    /// Non-nil whenever the factory's DB loader conforms to ``GalleryMediaReading`` (as
    /// `DBCarouselLoader` does): the object propagating filters to the galleries level.
    private(set) public var galleryFilterCoordinator: GalleryFilteringCoordinator<Filter>? = nil
    
    /// - Parameters:
    ///   - filteringStrategy: How multiple active filters combine (`nil` behaves as `.and`).
    ///   - emptyGalleryPolicy: What happens when the current gallery has no matching media.
    ///   - paywall: Forwarded untouched to `CarouselPageFromDB`; filtering and paywalling compose.
    public init(
        gallery: String? = nil,
        foreignKeys: SerializableGalleryForeignKeys,
        with pageFactory: (any MediaFactory)? = nil,
        componentsFactory: (any ZTronComponentsFactory),
        interactionsManagersFactory: (any ZTronInteractionsManagersFactory)? = nil,
        theme: any ZTronTheme = ZTronThemeProvider.default(),
        filteringStrategy: FilteringStrategy? = nil,
        emptyGalleryPolicy: EmptyGalleryFilteringPolicy = .showPlaceholder,
        paywall: (any CarouselPaywalling)? = nil
    ) {
        let resolvedPageFactory = pageFactory ?? BasicMediaFactory()
        
        let carousel = FilterableCarouselComponent<Filter>(
            with: resolvedPageFactory,
            medias: [],
            filteringStrategy: filteringStrategy
        )
        self.filteredCarousel = carousel
        
        super.init(
            gallery: gallery,
            foreignKeys: foreignKeys,
            with: resolvedPageFactory,
            componentsFactory: componentsFactory,
            interactionsManagersFactory: interactionsManagersFactory,
            theme: theme,
            carousel: carousel,
            paywall: paywall
        )
        
        if let reader = self.dbLoader as? (any GalleryMediaReading) {
            let coordinator = GalleryFilteringCoordinator<Filter>(
                reader: reader,
                model: carousel.filteringModel,
                policy: emptyGalleryPolicy
            )
            
            coordinator.setDelegate(coordinator.makeInteractionsManager(mediator: self.mediator))
            self.galleryFilterCoordinator = coordinator
        } else {
            #if DEBUG
            print("FilteredCarouselPageFromDB: the DB loader produced by the components factory (\(String(describing: type(of: self.dbLoader)))) does not conform to GalleryMediaReading. Media-level filtering keeps working, but galleries-level gating, desaturation and redirects are disabled.")
            #endif
        }
    }
    
    required public init?(coder: NSCoder) {
        return nil
    }
    
    // MARK: - Fluent filtering interface
    
    /// Declares (or replaces) the effect associated to `filter`. See
    /// `FilterableCarouselComponent.declareEffect(_:_:)`.
    @discardableResult
    public final func declareEffect(_ filter: Filter, _ effect: @escaping (any VisualMediaDescriptor) -> Bool) -> Self {
        let wasActive = self.filteredCarousel.activeFilters.contains(filter)
        self.filteredCarousel.declareEffect(filter, effect)
        
        if wasActive {
            self.galleryFilterCoordinator?.filtersDidChange()
        }
        
        return self
    }
    
    @discardableResult
    public final func activateFilter(_ filter: Filter) -> Self {
        self.filteredCarousel.activateFilter(filter)
        self.galleryFilterCoordinator?.filtersDidChange()
        return self
    }
    
    @discardableResult
    public final func disableFilter(_ filter: Filter) -> Self {
        self.filteredCarousel.disableFilter(filter)
        self.galleryFilterCoordinator?.filtersDidChange()
        return self
    }
    
    @discardableResult
    public final func disableAllFilters() -> Self {
        self.filteredCarousel.disableAllFilters()
        self.galleryFilterCoordinator?.filtersDidChange()
        return self
    }
    
    /// How multiple active filters combine. Assigning re-applies the filters at both levels.
    public final var filteringStrategy: FilteringStrategy? {
        get { self.filteredCarousel.filteringStrategy }
        set {
            self.filteredCarousel.filteringStrategy = newValue
            self.galleryFilterCoordinator?.filtersDidChange()
        }
    }
    
    public final var activeFilters: Set<Filter> {
        return self.filteredCarousel.activeFilters
    }
}

// MARK: - Backward-compatible, filterless construction

public extension FilteredCarouselPageFromDB where Filter == EmptyFilter {
    /// Creates a filterless page, indistinguishable in behavior from a plain `CarouselPageFromDB`.
    convenience init(
        gallery: String? = nil,
        foreignKeys: SerializableGalleryForeignKeys,
        with pageFactory: (any MediaFactory)? = nil,
        componentsFactory: (any ZTronComponentsFactory),
        interactionsManagersFactory: (any ZTronInteractionsManagersFactory)? = nil,
        theme: any ZTronTheme = ZTronThemeProvider.default()
    ) {
        self.init(
            gallery: gallery,
            foreignKeys: foreignKeys,
            with: pageFactory,
            componentsFactory: componentsFactory,
            interactionsManagersFactory: interactionsManagersFactory,
            theme: theme,
            filteringStrategy: nil
        )
    }
}
