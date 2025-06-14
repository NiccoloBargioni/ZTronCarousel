import UIKit
import SwiftUI

import ZTronSerializable
import ZTronCarouselCore
import ZTronObservation

@MainActor open class CarouselPageFromDB: IOS15LayoutLimitingViewController {
    public let mediator: MSAMediator = .init()

    private let pageFactory: any MediaFactory
    private let dbLoader: any AnyDBLoader
    private let carouselModel: (any AnyViewModel)
    private var searchController: (any AnySearchController)?
    public let topbarView: UIViewController?
    private(set) public var bottomBarView: (any AnyBottomBar)!
    private(set) public var captionView: (any AnyCaptionView)!

    private let requestedGalleryID: String?
    
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
        interactionsManagersFactory: (any ZTronInteractionsManagersFactory)? = nil
    ) {
        
        self.requestedGalleryID = gallery
        
        self.componentsFactory = componentsFactory
        self.interactionsManagersFactory = interactionsManagersFactory ?? DefaultZTronInteractionsManagerFactory()
        
        self.carouselModel = self.componentsFactory.makeViewModel()
        self.dbLoader = self.componentsFactory.makeDBLoader(with: foreignKeys)
        
        self.pageFactory = pageFactory ?? BasicMediaFactory()
        self.thePageVC = .init(with: self.pageFactory, medias: [])
                
        self.topbarView = self.componentsFactory.makeTopbar(mediator: self.mediator)
        self.bottomBarView = nil
        
        super.init(nibName: nil, bundle: nil)
        
        self.makeConstraintsStrategy()
        
        Task(priority: .userInitiated) {
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
                try self.dbLoader.loadFirstLevelGalleries(gallery)
            }
        }
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()

        self.view.layer.masksToBounds = true
                
        view.backgroundColor = .systemBackground
        
        self.view.addSubview(self.scrollView)
        self.scrollView.translatesAutoresizingMaskIntoConstraints = false
        self.scrollView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor).isActive = true
        self.scrollView.rightAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.rightAnchor).isActive = true
        self.scrollView.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor).isActive = true
        self.scrollView.leftAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leftAnchor).isActive = true
        
        self.scrollView.layer.zPosition = 2.0
        
        if let topbarView = self.topbarView {
            topbarView.willMove(toParent: self)
            self.addChild(topbarView)
            self.scrollView.addSubview(topbarView.view)
        
            if let cs = self.constraintsStrategy as? any CarouselWithTopbarConstraintsStrategy {
                cs.makeTopbarConstraints(for: self.isPortrait ? .portrait : .landscapeLeft)
            }
            
            if !self.isPortrait {
                topbarView.view.isHidden = true
            } else {
                topbarView.view.isHidden = false
            }
                    
            topbarView.view.setContentHuggingPriority(.defaultHigh, for: .vertical)
            topbarView.view.layer.zPosition = 3.0
        }

        self.scrollView.addSubview(myContainerView)
        self.constraintsStrategy.makePageWrapperConstraints(for: self.isPortrait ? .portrait : .landscapeLeft)
        
        self.thePageVC.willMove(toParent: self)
        addChild(thePageVC)
        
        thePageVC.view.translatesAutoresizingMaskIntoConstraints = false
        myContainerView.addSubview(thePageVC.view)
        
        NSLayoutConstraint.activate([
            thePageVC.view.topAnchor.constraint(equalTo: thePageVC.view.superview!.safeAreaLayoutGuide.topAnchor),
            thePageVC.view.rightAnchor.constraint(equalTo: thePageVC.view.superview!.safeAreaLayoutGuide.rightAnchor),
            thePageVC.view.bottomAnchor.constraint(equalTo: thePageVC.view.superview!.safeAreaLayoutGuide.bottomAnchor),
            thePageVC.view.leftAnchor.constraint(equalTo: thePageVC.view.superview!.safeAreaLayoutGuide.leftAnchor),
        ])
        
        
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
        
        
        if !self.isPortrait {
            self.bottomBarView.isHidden = true
        }
        
        self.bottomBarView.setDelegate(
            self.interactionsManagersFactory
                .makeBottomBarInteractionsManager(owner: self.bottomBarView, mediator: self.mediator)
        )
    
        self.captionView = componentsFactory.makeCaptionView()
        
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
        self.captionView.setDelegate(
            self.interactionsManagersFactory.makeCaptionViewInteractionsManager(owner: self.captionView, mediator: self.mediator)
        )
        
        thePageVC.didMove(toParent: self)
        self.topbarView?.didMove(toParent: self)
        
        self.thePageVC.setDelegate(
            self.interactionsManagersFactory
                .makeCarouselComponentInteractionsManager(owner: self.thePageVC, mediator: self.mediator)
        )
        
        scrollViewBottomContentGuide = self.scrollView.contentLayoutGuide.bottomAnchor.constraint(
            equalTo: isPortrait ?
                self.captionView.safeAreaLayoutGuide.bottomAnchor :
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
                to: myContainerView.frame.width > myContainerView.frame.height ? .landscapeLeft : .portrait,
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
                    self.topbarView?.view.isHidden = false
                    self.bottomBarView.isHidden = false
                    self.captionView.isHidden = false
                    self.captionView.superview?.isHidden = false
                    self.updateScrollViewContentBottom(constraint: &self.scrollViewBottomContentGuide)
                } else {
                    self.topbarView?.view.isHidden = true
                    self.bottomBarView.isHidden = true
                    self.captionView.isHidden = true
                    self.captionView.superview?.isHidden = true
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
                    
                    self.topbarView?.view.invalidateIntrinsicContentSize()
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
                    self.captionView.safeAreaLayoutGuide.bottomAnchor :
                    self.myContainerView.safeAreaLayoutGuide.bottomAnchor
                )
        } else {
            constraint = self.scrollView.contentLayoutGuide.bottomAnchor.constraint(
                equalTo: self.isPortrait ?
                    self.captionView.safeAreaLayoutGuide.bottomAnchor :
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
            try self.dbLoader.loadFirstLevelGalleries(nil)
        }
    }

    open func makeConstraintsStrategy() {
        if self.topbarView != nil {
            self.constraintsStrategy = CarouselPageFromDBWithTopbarConstraintsStrategy(owner: self)
        } else {
            self.constraintsStrategy = CarouselPageFromDBTopbarlessConstraintsStrategy(owner: self)
        }
    }
    
}


