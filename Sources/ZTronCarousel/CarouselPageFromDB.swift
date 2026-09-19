import UIKit
import SwiftUI

import ZTronSerializable
import ZTronCarouselCore
import ZTronObservation
import ZTronTheme
import ZTronDataModel

@MainActor open class CarouselPageFromDB: IOS15LayoutLimitingViewController {
    public let mediator: MSAMediator = .init()
    
    open var theme: (any ZTronTheme)
    private let pageFactory: any MediaFactory
    /// The loader created by the components factory. Exposed so that subclasses (e.g.
    /// `FilteredCarouselPageFromDB`) can attach collaborators that need read access to the same
    /// database scope, such as `GalleryMediaReading`.
    public let dbLoader: any AnyDBLoader
    public let carouselModel: (any AnyViewModel)
    private var searchController: (any AnySearchController)?
    private(set) public var topbarViews: [UIViewController] = []
    private(set) public var bottomBarView: (any AnyBottomBar)!
    
    /// The paywall gating this page's bottom bar contents, if any. Resolution order: the instance
    /// passed to `init(paywall:)` (or later via `setPaywall(_:)`), falling back to
    /// `componentsFactory.makePaywall()`.
    private(set) public var paywall: (any CarouselPaywalling)? = nil
    
    /// External component registrations (see `registerComponents(lifecycle:_:)`). Marked
    /// `nonisolated(unsafe)` so the deinit safety net can tear them down; mutated on the main
    /// actor only.
    nonisolated(unsafe) private var externalRegistrations: [ExternalMediatorRegistration] = []
    nonisolated(unsafe) private var externalComponentsObserver: ExternalComponentsLifecycleObserver? = nil
    private(set) public var captionView: (any AnyCaptionView)!

    private let requestedGalleryID: String?
    private var gallerySubtreeLength: Int? = nil
    
    public let myContainerView: UIView = {
        let v = UIView()
        v.backgroundColor = .black
        return v
    }()
    
    private(set) public var thePageVC: CarouselComponent!
    private(set) public var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.delaysContentTouches = false
        
        return scrollView
    }()
    
    open var constraintsStrategy: ConstraintsStrategy!
    
    private let componentsFactory: any ZTronComponentsFactory
    private let interactionsManagersFactory: any ZTronInteractionsManagersFactory

    private var scrollViewBottomContentGuide: NSLayoutConstraint!

    
    private var limitViewDidLayoutCalls: Int = Int.max
    // track current view width
    private var curWidth: CGFloat = 0.0
    
    public var isPortrait: Bool {
        if UIDevice.current.orientation.isValidInterfaceOrientation {
            return UIDevice.current.orientation.isPortrait
        } else {
            let scenes = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
            let keyWindow = scenes.first(where: { $0.keyWindow != nil })?.keyWindow ?? scenes.first?.keyWindow

            if let keyWindowBounds = keyWindow?.screen.bounds {
                return keyWindowBounds.height > keyWindowBounds.width
            } else {
                fatalError("Unable to infer initial device orientation") // if not wrapped in UINavigationController this can happen
            }
        }
    }
    
    public init(
        gallery: String? = nil,
        foreignKeys: SerializableGalleryForeignKeys,
        with pageFactory: (any MediaFactory)? = nil,
        componentsFactory: (any ZTronComponentsFactory),
        interactionsManagersFactory: (any ZTronInteractionsManagersFactory)? = nil,
        theme: any ZTronTheme = ZTronThemeProvider.default(),
        carousel: CarouselComponent? = nil,
        paywall: (any CarouselPaywalling)? = nil
    ) {
        self.theme = theme
        self.requestedGalleryID = gallery
        
        self.componentsFactory = componentsFactory
        self.interactionsManagersFactory = interactionsManagersFactory ?? DefaultZTronInteractionsManagerFactory()
        
        self.carouselModel = self.componentsFactory.makeViewModel()
        self.dbLoader = self.componentsFactory.makeDBLoader(with: foreignKeys)
        
        self.pageFactory = pageFactory ?? BasicMediaFactory()
        self.thePageVC = carousel ?? .init(with: self.pageFactory, medias: [])
        self.paywall = paywall ?? componentsFactory.makePaywall()
        
        super.init(nibName: nil, bundle: nil)
        
        do {
            try DBMS.transaction { dbConnection in
                if let gallery = gallery {
                    if let maxDepth = try? CRUD.readMaxDepthOfSubgalleryRootedInGallery(
                        for: dbConnection,
                        master: gallery,
                        game: foreignKeys.getGame(),
                        map: foreignKeys.getMap(),
                        tab: foreignKeys.getTab(),
                        tool: foreignKeys.getTool()
                    ) {
                        self.gallerySubtreeLength = maxDepth
                    } else {
                        fatalError("Unable to read maximum depth of \(gallery)")
                    }
                } else {
                    if let maxDepth = try? CRUD.readMaxDepthOfGalleryForTool(
                        for: dbConnection,
                        game: foreignKeys.getGame(),
                        map: foreignKeys.getMap(),
                        tab: foreignKeys.getTab(),
                        tool: foreignKeys.getTool()
                    ) {
                        self.gallerySubtreeLength = maxDepth
                    } else {
                        fatalError("Unable to read maximum depth of gallery rooted in \(foreignKeys.getTool())")
                    }
                }
                
                return .commit
            }
        } catch {
            fatalError(error.localizedDescription)
        }
        
        if let gallerySubtreeLength = self.gallerySubtreeLength {
            for nestingLevel in 0..<gallerySubtreeLength {
                if let topbar = self.componentsFactory.makeTopbar(
                    mediator: self.mediator,
                    nestingLevel: nestingLevel,
                    maximumDepth: gallerySubtreeLength
                ) {
                    self.topbarViews.append(topbar)
                } else {
                    fatalError("Unable to make topbar for level \(nestingLevel)")
                }
            }
        }
        
        self.bottomBarView = nil
        
        
        self.makeConstraintsStrategy()
        
        
        Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            self.carouselModel.viewModel = self
            
            self.carouselModel.setDelegate(
                self.interactionsManagersFactory
                    .makeCarouselInteractionsManager(owner: self.carouselModel, mediator: self.mediator)
            )
            
            self.dbLoader.setDelegate(
                self.interactionsManagersFactory
                    .makeDBLoaderInteractionsManager(owner: self.dbLoader, mediator: self.mediator)
            )
            
            if let pgFactory = pageFactory as? any Notifiable {
                pgFactory.setMediator(self.mediator)
            }
            
            if let pgFactory = pageFactory as? any PaywallInjectable {
                pgFactory.setPaywallProvider { [weak self] in self?.paywall }
            }
            
            if let searchController = self.componentsFactory.makeSearchController() {
                self.searchController = searchController
                searchController.setDelegate(
                    self.interactionsManagersFactory.makeSearchControllerInteractionsManager(owner: searchController, mediator: self.mediator),
                    ofType: MSAInteractionsManager.self
                )
            } else {
                self.searchController = nil
            }
            
            
            Task(priority: .high) {
                self.dbLoader.setCurrentDepth(-1)

                do {
                    try self.dbLoader.loadFirstLevelGalleries(gallery)
                } catch {
                    fatalError(error.localizedDescription)
                }
            }
        }
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()

        self.view.layer.masksToBounds = true
                
        let backgroundView = UIHostingController(rootView: AppBackground(theme: self.theme.erasedToAnyTheme()))
        backgroundView.willMove(toParent: self)
        self.addChild(backgroundView)
        self.view.addSubview(backgroundView.view)
        backgroundView.didMove(toParent: self)
        
        backgroundView.view.translatesAutoresizingMaskIntoConstraints = false
        
        if #available(iOS 16.0, *) {
            backgroundView.sizingOptions = .intrinsicContentSize
        }
        
        NSLayoutConstraint.activate([
            backgroundView.view.topAnchor.constraint(equalTo: self.view.topAnchor),
            backgroundView.view.rightAnchor.constraint(equalTo: self.view.rightAnchor),
            backgroundView.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            backgroundView.view.leftAnchor.constraint(equalTo: self.view.leftAnchor)
        ])
        
        self.view.addSubview(self.scrollView)
        self.scrollView.translatesAutoresizingMaskIntoConstraints = false
        self.scrollView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor).isActive = true
        self.scrollView.rightAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.rightAnchor).isActive = true
        self.scrollView.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor).isActive = true
        self.scrollView.leftAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leftAnchor).isActive = true
        
        self.scrollView.layer.zPosition = 2.0
        
        for topbarView in self.topbarViews {
            topbarView.willMove(toParent: self)
            self.addChild(topbarView)
            self.scrollView.addSubview(topbarView.view)
            
            if !self.isPortrait {
                topbarView.view.isHidden = true
            } else {
                topbarView.view.isHidden = false
            }
            
            topbarView.view.setContentHuggingPriority(.defaultHigh, for: .vertical)
            topbarView.view.layer.zPosition = 3.0
        }

        self.scrollView.addSubview(myContainerView)
        
        self.thePageVC.willMove(toParent: self)
        addChild(thePageVC)
        
        thePageVC.view.translatesAutoresizingMaskIntoConstraints = false
        myContainerView.addSubview(thePageVC.view)
                
        
        self.bottomBarView = componentsFactory.makeBottomBar()
        self.bottomBarView.layer.zPosition = 3.0
        
        self.scrollView.addSubview(self.bottomBarView)

        self.bottomBarView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            self.bottomBarView.topAnchor.constraint(equalTo: self.thePageVC.view.bottomAnchor, constant: 5.0),
            self.bottomBarView.leftAnchor.constraint(equalTo: self.thePageVC.view.leftAnchor),
            self.bottomBarView.rightAnchor.constraint(equalTo: self.thePageVC.view.rightAnchor),
            self.bottomBarView.heightAnchor.constraint(equalToConstant: 44.0)
        ])
        
        
        if let cs = self.constraintsStrategy as? any CarouselWithTopbarConstraintsStrategy {
            if let gallerySubtreeLength = self.gallerySubtreeLength {
                for nestingLevel in 0..<gallerySubtreeLength {
                    cs.makeTopbarConstraints(
                        for: self.isPortrait ? .portrait : .landscapeLeft,
                        nestingLevel: nestingLevel,
                        maxDepth: gallerySubtreeLength
                    )
                }
            } else {
                fatalError("Unable to acquire subtree length rooted in \(String(describing: self.requestedGalleryID))/\(self.dbLoader.fk.getTool())")
            }
        }
        
        self.constraintsStrategy.makePageWrapperConstraints(for: self.isPortrait ? .portrait : .landscapeLeft)

        NSLayoutConstraint.activate([
            thePageVC.view.topAnchor.constraint(equalTo: thePageVC.view.superview!.safeAreaLayoutGuide.topAnchor),
            thePageVC.view.rightAnchor.constraint(equalTo: thePageVC.view.superview!.safeAreaLayoutGuide.rightAnchor),
            thePageVC.view.bottomAnchor.constraint(equalTo: thePageVC.view.superview!.safeAreaLayoutGuide.bottomAnchor),
            thePageVC.view.leftAnchor.constraint(equalTo: thePageVC.view.superview!.safeAreaLayoutGuide.leftAnchor),
        ])

        
        if !self.isPortrait {
            self.bottomBarView.isHidden = true
        }
        
        self.bottomBarView.setDelegate(
            self.interactionsManagersFactory
                .makeBottomBarInteractionsManager(owner: self.bottomBarView, mediator: self.mediator)
        )
        
        self.bottomBarView.setPaywall(self.paywall, presentingFrom: self)
    
        self.captionView = componentsFactory.makeCaptionView()
        
        if self.captionView.displayStrategy == .below {
            let captionViewContainer = BottomSeparatedUIView()
            self.scrollView.addSubview(captionViewContainer)
            captionViewContainer.addSubview(captionView)
            
            captionViewContainer.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                captionViewContainer.topAnchor.constraint(equalTo: self.bottomBarView.bottomAnchor),
                captionViewContainer.leftAnchor.constraint(equalTo: self.bottomBarView.leftAnchor),
                captionViewContainer.rightAnchor.constraint(equalTo: self.bottomBarView.rightAnchor),
                captionViewContainer.bottomAnchor.constraint(equalTo: self.captionView.bottomAnchor, constant: 10)
            ])
            
            captionViewContainer.backgroundColor = UIColor.tertiarySystemGroupedBackground.withAlphaComponent(0.325)
            
            self.captionView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                self.captionView.topAnchor.constraint(equalTo: self.captionView.superview!.topAnchor, constant: 10),
                self.captionView.rightAnchor.constraint(equalTo: self.captionView.superview!.rightAnchor, constant: -10),
                self.captionView.leftAnchor.constraint(equalTo: self.captionView.superview!.leftAnchor, constant: 10)
            ])
            
            self.captionView.setContentHuggingPriority(.defaultHigh, for: .vertical)
            
            self.view.bringSubviewToFront(captionView)
        } else {
            self.scrollView.addSubview(self.captionView)
            
            self.captionView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                self.captionView.topAnchor.constraint(equalTo: self.thePageVC.view.safeAreaLayoutGuide.topAnchor),
                self.captionView.rightAnchor.constraint(equalTo: self.thePageVC.view.safeAreaLayoutGuide.rightAnchor),
                self.captionView.bottomAnchor.constraint(equalTo: self.thePageVC.view.safeAreaLayoutGuide.bottomAnchor),
                self.captionView.leftAnchor.constraint(equalTo: self.thePageVC.view.safeAreaLayoutGuide.leftAnchor),
            ])
            
            self.captionView.layer.opacity = .zero
            self.captionView.isHidden = true
        }
        
        self.captionView.setDelegate(
            self.interactionsManagersFactory.makeCaptionViewInteractionsManager(owner: self.captionView, mediator: self.mediator)
        )
        
        thePageVC.didMove(toParent: self)
        for topbar in self.topbarViews {
            topbar.didMove(toParent: self)
        }
        
        self.thePageVC.setDelegate(
            self.interactionsManagersFactory
                .makeCarouselComponentInteractionsManager(owner: self.thePageVC, mediator: self.mediator)
        )
        
        scrollViewBottomContentGuide = self.scrollView.contentLayoutGuide.bottomAnchor.constraint(
            equalTo: isPortrait ?
                self.captionView.displayStrategy == .below ?
                    self.captionView.safeAreaLayoutGuide.bottomAnchor : self.thePageVC.view!.superview!.bottomAnchor :
                self.myContainerView.safeAreaLayoutGuide.bottomAnchor
            )

        self.scrollViewBottomContentGuide.isActive = true
        
        self.constraintsStrategy.makeScrollViewContentConstraints(for: self.isPortrait ? .portrait : .landscapeLeft)
    }
    
    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if #unavailable(iOS 16.0) {
            guard self.limitViewDidLayoutCalls > 0 else { return }
            
            self.limitViewDidLayoutCalls -= 1
        }
                
        if curWidth != myContainerView.frame.width {
            thePageVC.view.layer.cornerRadius = 5.0;
            thePageVC.view.layer.masksToBounds = false
            thePageVC.view.layer.shadowOffset = CGSize.init(width: 0, height: 5)
            thePageVC.view.layer.shadowColor = self.traitCollection.userInterfaceStyle == .light ? UIColor.gray.cgColor : UIColor.clear.cgColor
            thePageVC.view.layer.shadowRadius = 3
            thePageVC.view.layer.shadowOpacity = 0.4

            
            curWidth = myContainerView.frame.width
            self.constraintsStrategy.updatePageWrapperConstraintsForTransition(
                to: self.view.frame.size.width > self.view.frame.size.height ? .landscapeLeft : .portrait,
                sizeAfterTransition: myContainerView.superview!.frame.size
            )
        }
    }
    
    
    internal final func computeContentSizeThatFits() -> CGSize {
        return CGSize.sizeThatFits(containerSize: self.view.safeAreaLayoutGuide.layoutFrame.size, containedAR: 16.0/9.0)
    }
    
    override open func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        if #unavailable(iOS 16) {
            self.limitViewDidLayoutCalls = 1
        }
        
        coordinator.animate { _ in
            UIView.animate(withDuration: 0.25) {
                self.constraintsStrategy.updatePageWrapperConstraintsForTransition(
                    to: size.width > size.height ? .landscapeLeft : .portrait,
                    sizeAfterTransition: size
                )
                
                if size.width < size.height {
                    for topbarview in self.topbarViews {
                        topbarview.view.isHidden = false
                    }
                    
                    self.bottomBarView.isHidden = false
                    self.captionView.isHidden = false
                    
                    if self.captionView.displayStrategy == .below {
                        self.captionView.superview?.isHidden = false
                    }
                    
                    self.updateScrollViewContentBottom(constraint: &self.scrollViewBottomContentGuide)
                } else {
                    for topbar in self.topbarViews {
                        topbar.view.isHidden = true
                    }
                    
                    self.bottomBarView.isHidden = true
                    self.captionView.isHidden = true
                    
                    if self.captionView.displayStrategy == .below {
                        self.captionView.superview?.isHidden = true
                    }

                    self.updateScrollViewContentBottom(constraint: &self.scrollViewBottomContentGuide)
                }
                
                self.constraintsStrategy.updateScrollViewContentConstraintsForTransition(
                    to: .portrait,
                    sizeAfterTransition: size
                )
                    
                self.view.layoutIfNeeded()
                
            } completion: { @MainActor ended in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    if #unavailable(iOS 16) {
                        self.limitViewDidLayoutCalls = Int.max
                    }
                    
                    for topbarView in self.topbarViews {
                        topbarView.view.invalidateIntrinsicContentSize()
                    }
                    
                    super.onRotationCompletion()
                }
            }
        }
    }
    
    @MainActor open func updateScrollViewContentBottom(constraint: inout NSLayoutConstraint) {
        constraint.isActive = false

        if UIDevice.current.orientation.isValidInterfaceOrientation {
            constraint = self.scrollView.contentLayoutGuide.bottomAnchor.constraint(
                equalTo: UIDevice.current.orientation.isPortrait ?
                    self.constraintsStrategy.viewBelowCarousel().bottomAnchor :
                    self.myContainerView.safeAreaLayoutGuide.bottomAnchor
                )
        } else {
            constraint = self.scrollView.contentLayoutGuide.bottomAnchor.constraint(
                equalTo: self.isPortrait ?
                    self.constraintsStrategy.viewBelowCarousel().bottomAnchor :
                    self.myContainerView.safeAreaLayoutGuide.bottomAnchor
                )
        }
        constraint.isActive = true
    }
    
    @MainActor public final func updateScrollViewContentBottom() {
        self.updateScrollViewContentBottom(constraint: &self.scrollViewBottomContentGuide)
    }
    
    public final func reloadImages() throws {
        if let gallery = self.requestedGalleryID {
            try self.dbLoader.loadImagesForGallery(gallery)
        } else {
            self.dbLoader.setCurrentDepth(-1)
            try self.dbLoader.loadFirstLevelGalleries(nil)
        }
    }

    open func makeConstraintsStrategy() {
        self.constraintsStrategy = self.componentsFactory.makeConstraintsStrategy(owner: self, self.topbarViews.count > 0)
    }
    
    /// Replaces the paywall at runtime and propagates it to the bottom bar. `ZTronCarouselView`
    /// invokes this from `updateUIViewController` when the accumulated `.paywalled` rules change
    /// shape; pass `nil` to remove any gating.
    public final func setPaywall(_ paywall: (any CarouselPaywalling)?) {
        self.paywall = paywall
        
        if self.isViewLoaded && self.bottomBarView != nil {
            self.bottomBarView.setPaywall(paywall, presentingFrom: self)
        }
        
        // Placeables (outline, bounding circle) are baked into the page's view controller at
        // construction time by the page factory, unlike the bar's contents, which are gated at tap
        // time. Re-presenting the currently visible descriptor at its own index forces
        // CarouselComponent to rebuild that one view controller through the (paywall-aware) page
        // factory, so a gating change is reflected without waiting for the user to swipe away and
        // back. A no-op when no media is currently displayed (empty/placeholder state).
        if let currentDescriptor = self.thePageVC.currentVisibleMediaDescriptor {
            self.thePageVC.replaceMedia(with: currentDescriptor, at: self.thePageVC.currentPage, shouldReplaceViewController: true)
        }
    }
    
    public final func toggleCaptionOverlay() {
        if self.captionView.isHidden {
            self.captionView.isHidden = false
            
            UIView.animate(withDuration: 0.3) {
                self.captionView.layer.opacity = 1.0
            }
        } else {
            UIView.animate(withDuration: 0.3) {
                self.captionView.layer.opacity = 0.0
            } completion: { _ in
                self.captionView.isHidden = true
            }
        }
    }
    
    /// Registers `component` in this page's mediator, with no lifecycle management: the caller
    /// owns retention and teardown. The component's delegate **must already be set** (the mediator
    /// traps on delegate-less components). Prefer `registerComponents(lifecycle:_:)`, which
    /// manages retention, teardown and — with `.media` — re-attachment for you.
    public final func registerAlongsideCarousel(_ component: any Component) {
        self.mediator.register(component)
    }
    
    // MARK: - Managed external components
    
    /// Registers client components in this page's mediator, alongside the built-in ones (carousel,
    /// DB loader, topbars, bottom bar, caption, search), with a managed lifecycle.
    ///
    /// The setup closure receives the page's mediator; it must create the components, wire each
    /// one's interactions manager via `setDelegate(_:)` — which registers it, following the same
    /// pattern every built-in component uses — and return what it registered. The page retains the
    /// returned components and tears them down (`setDelegate(nil)`, then a defensive
    /// `unregister`) according to `lifecycle`:
    ///
    /// - ``MediatorRegistrationLifecycle/media``: the closure runs when an image appears and its
    ///   components are torn down when that image leaves the screen (swipe, gallery change,
    ///   variant change), then the closure runs again for the new image. While no media is
    ///   displayed, nothing stays attached.
    /// - ``MediatorRegistrationLifecycle/page``: the closure runs once, immediately; its
    ///   components persist across image and gallery changes and are torn down when the page is
    ///   popped or dismissed (with deallocation as a safety net).
    ///
    /// ```swift
    /// page.registerComponents(lifecycle: .media) { mediator in
    ///     let heatmap = HeatmapOverlayComponent()
    ///     heatmap.setDelegate(HeatmapInteractionsManager(owner: heatmap, mediator: mediator))
    ///     return [heatmap]
    /// }
    /// ```
    @discardableResult
    public final func registerComponents(
        lifecycle: MediatorRegistrationLifecycle = .page,
        _ setup: @escaping @MainActor (MSAMediator) -> [any Component]
    ) -> Self {
        let registration = ExternalMediatorRegistration(lifecycle: lifecycle, setup: setup)
        self.externalRegistrations.append(registration)
        
        switch lifecycle {
            case .page:
                registration.live = setup(self.mediator)
                
            case .media:
                self.makeExternalComponentsObserverIfNeeded()
                
                if self.thePageVC.currentVisibleMediaDescriptor != nil {
                    registration.live = setup(self.mediator)
                }
        }
        
        return self
    }
    
    private final func makeExternalComponentsObserverIfNeeded() {
        guard self.externalComponentsObserver == nil else { return }
        
        let observer = ExternalComponentsLifecycleObserver { [weak self] in
            self?.externalMediaDidChange()
        }
        
        observer.setDelegate(observer.makeInteractionsManager(mediator: self.mediator))
        self.externalComponentsObserver = observer
    }
    
    /// Cycles every `.media` registration: tears the previous components down and, if a media is
    /// actually on display (the empty-results placeholder doesn't count), runs the setup again so
    /// the fresh components attach to the new image.
    private final func externalMediaDidChange() {
        guard !self.externalRegistrations.isEmpty else { return }
        
        let isMediaOnDisplay = self.thePageVC.currentVisibleMediaDescriptor != nil
        
        for registration in self.externalRegistrations where registration.lifecycle == .media {
            Self.teardown(registration, mediator: self.mediator)
            
            if isMediaOnDisplay {
                registration.live = registration.setup(self.mediator)
            }
        }
    }
    
    nonisolated private static func teardown(_ registration: ExternalMediatorRegistration, mediator: MSAMediator) {
        registration.live.forEach { component in
            component.setDelegate(nil)
            mediator.unregister(component, or: .ignore)
        }
        
        registration.live = []
    }
    
    nonisolated private final func teardownAllExternalComponents() {
        self.externalRegistrations.forEach { Self.teardown($0, mediator: self.mediator) }
        
        if let observer = self.externalComponentsObserver {
            observer.setDelegate(nil)
            self.mediator.unregister(observer, or: .ignore)
            self.externalComponentsObserver = nil
        }
    }
    
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if self.isMovingFromParent || self.isBeingDismissed {
            self.teardownAllExternalComponents()
        }
    }
    
    deinit {
        self.teardownAllExternalComponents()
    }
}


