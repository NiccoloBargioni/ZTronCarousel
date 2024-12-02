import UIKit
import SnapKit
import SwiftUI

import ZTronSerializable
import ZTronCarouselCore
import ZTronObservation

@MainActor open class CarouselPageWithTopbar: UIViewController {
    private let pageFactory: any MediaFactory
    private let dbLoader: any AnyDBLoader
    private let carouselModel: (any AnyViewModel)

    private let componentsFactory: any ZTronComponentsFactory
    private let interactionsManagersFactory: any ZTronInteractionsManagersFactory

    // this will hold the page view controller
    private let myContainerView: UIView = {
        let v = UIView()
        v.backgroundColor = .black
        return v
    }()
    
    // we will add a UIPageViewController as a child VC
    private(set) public var thePageVC: CarouselComponent!
    
    // this will be used to change the page view controller height based on
    //    view width-to-height (portrait/landscape)
    // I know this could be done with a SnapKit object, but I don't use SnapKit...
    private var pgvcHeight: NSLayoutConstraint!
    private var pgvcWidth: NSLayoutConstraint!
    private var pgvcTop: NSLayoutConstraint!
    private var topbarWidth: NSLayoutConstraint!
    
    // track current view width
    private var curWidth: CGFloat = 0.0
    
    private(set) public var bottomBarView: (any AnyBottomBar)!
    private(set) public var captionView: (any AnyCaptionView)!
    private(set) public var wrappingScrollView: UIScrollView = UIScrollView(frame: .zero)
    private(set) public var scrollViewContent: UIView = UIView(frame: .zero)
    
    public let mediator: MSAMediator = .init()
    public let topbarView: UIViewController
    
    public init(
        foreignKeys: SerializableGalleryForeignKeys,
        with pageFactory: (any MediaFactory)? = nil,
        componentsFactory: (any ZTronComponentsFactory)? = nil,
        interactionsManagersFactory: (any ZTronInteractionsManagersFactory)? = nil
    ) {
        
        self.componentsFactory = componentsFactory ?? DefaultZtronComponentsFactory()
        self.interactionsManagersFactory = interactionsManagersFactory ?? DefaultZTronInteractionsManagerFactory()
        
        self.carouselModel = self.componentsFactory.makeViewModel()
        self.dbLoader = self.componentsFactory.makeDBLoader(with: foreignKeys)
        
        self.pageFactory = pageFactory ?? BasicMediaFactory()
        self.thePageVC = .init(with: self.pageFactory, medias: [])
        
        thePageVC.view.layer.cornerRadius = 5.0;
        thePageVC.view.layer.masksToBounds = false
        thePageVC.view.layer.shadowOffset = CGSize.init(width: 0, height: 5)
        thePageVC.view.layer.shadowColor = UIColor.gray.cgColor
        thePageVC.view.layer.shadowRadius = 3
        thePageVC.view.layer.shadowOpacity = 0.4
        
        self.topbarView = self.componentsFactory.makeTopbar(mediator: self.mediator)
        self.bottomBarView = nil
        
        super.init(nibName: nil, bundle: nil)
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
            
            Task(priority: .high) {
                try self.dbLoader.loadFirstLevelGalleries()
            }
        }
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.title = "Memory Charms"
        
        // so we can see the view / page view controller framing
        view.backgroundColor = .systemBackground
        
        self.view.addSubview(self.wrappingScrollView)
        self.wrappingScrollView.addSubview(self.scrollViewContent)
        
        self.wrappingScrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            self.wrappingScrollView.topAnchor.constraint(equalTo: self.wrappingScrollView.superview!.safeAreaLayoutGuide.topAnchor),
            self.wrappingScrollView.rightAnchor.constraint(equalTo: self.wrappingScrollView.superview!.safeAreaLayoutGuide.rightAnchor),
            self.wrappingScrollView.bottomAnchor.constraint(equalTo: self.wrappingScrollView.superview!.safeAreaLayoutGuide.bottomAnchor),
            self.wrappingScrollView.leftAnchor.constraint(equalTo: self.wrappingScrollView.superview!.safeAreaLayoutGuide.leftAnchor)
        ])
        
        
        self.topbarView.willMove(toParent: self)
        self.addChild(self.topbarView)
        self.scrollViewContent.addSubview(self.topbarView.view)
        
        self.topbarView.view.snp.makeConstraints { make in
            make.left.right.top.equalTo(self.topbarView.view.superview!.safeAreaLayoutGuide)
            make.height.equalTo(self.topbarView.view.intrinsicContentSize.height)
        }
        
        if UIDevice.current.orientation.isValidInterfaceOrientation {
            if !UIDevice.current.orientation.isPortrait {
                self.topbarView.view.isHidden = true
            }
        }
        
        self.topbarView.view.setContentHuggingPriority(.defaultHigh, for: .vertical)

        // add myContainerView
        self.scrollViewContent.addSubview(myContainerView)
        
        myContainerView.snp.makeConstraints { make in
            make.centerX.equalTo(self.myContainerView.superview!.safeAreaLayoutGuide)
        }

            
        let size = self.computeContentSizeThatFits()

        // this will be updated in viewDidLayoutSubviews
        pgvcHeight = myContainerView.heightAnchor.constraint(equalToConstant: size.height)
        pgvcHeight.isActive = true

        pgvcWidth = myContainerView.widthAnchor.constraint(equalToConstant: size.width)
        pgvcWidth.isActive = true
        
        if UIDevice.current.orientation == .portrait {
            pgvcTop = myContainerView.topAnchor.constraint(equalTo: self.topbarView.view.safeAreaLayoutGuide.bottomAnchor)
        } else {
            pgvcTop = myContainerView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor)
        }
        
        pgvcTop.isActive = true
        self.thePageVC.willMove(toParent: self)
        addChild(thePageVC)
        
        // set the "data"
                
        // add the page VC's view to our container view
        myContainerView.addSubview(thePageVC.view)
        
        thePageVC.view.snp.makeConstraints { make in
            make.left.top.right.bottom.equalTo(thePageVC.view.superview!.safeAreaLayoutGuide)
        }
        
        self.bottomBarView = componentsFactory.makeBottomBar()
        
        self.scrollViewContent.addSubview(self.bottomBarView)

        self.bottomBarView.snp.makeConstraints { make in
            make.left.right.equalTo(thePageVC.view)
            make.top.equalTo(thePageVC.view.snp.bottom).offset(5)
            make.height.equalTo(44)
        }
                
        self.bottomBarView.setDelegate(
            self.interactionsManagersFactory
                .makeBottomBarInteractionsManager(owner: self.bottomBarView, mediator: self.mediator)
        )
    
        self.captionView = componentsFactory.makeCaptionView()
        
        let captionViewContainer = BottomSeparatedUIView()
        self.scrollViewContent.addSubview(captionViewContainer)
        captionViewContainer.addSubview(captionView)
        
        captionViewContainer.snp.makeConstraints { make in
            make.top.equalTo(self.bottomBarView.snp.bottom)
            make.left.right.equalTo(self.bottomBarView)
            make.bottom.equalTo(self.captionView!.snp.bottom)
        }
        
        captionViewContainer.backgroundColor = UIColor.tertiarySystemGroupedBackground.withAlphaComponent(0.325)

        self.captionView.snp.makeConstraints { make in
            make.left.top.right.equalToSuperview().inset(10)
        }
        
        self.captionView.setContentHuggingPriority(.defaultHigh, for: .vertical)
        
        
        self.view.bringSubviewToFront(captionView)
        self.captionView.setDelegate(
            self.interactionsManagersFactory.makeCaptionViewInteractionsManager(owner: self.captionView, mediator: self.mediator)
        )
        
        
        thePageVC.didMove(toParent: self)
        self.topbarView.didMove(toParent: self)
        
        self.thePageVC.setDelegate(
            self.interactionsManagersFactory
                .makeCarouselComponentInteractionsManager(owner: self.thePageVC, mediator: self.mediator)
        )
        
        self.view.layoutIfNeeded()

        self.updateScrollViewContentSize()
    }
    
    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
                
        // only execute this code block if the view frame has changed
        //    such as on device rotation
        if curWidth != myContainerView.frame.width {
            curWidth = myContainerView.frame.width
            
            // cannot directly change a constraint multiplier, so
            //    deactivate / create new / reactivate
            let size = self.computeContentSizeThatFits()
            
            pgvcHeight.isActive = false
            pgvcHeight = self.myContainerView.heightAnchor.constraint(equalToConstant: size.height)
            pgvcHeight.isActive = true
            
            pgvcWidth.isActive = false
            pgvcWidth = self.myContainerView.widthAnchor.constraint(equalToConstant: size.width)
            pgvcWidth.isActive = true
            
            self.updateScrollViewContentSize()
        }
        
        self.topbarView.view.invalidateIntrinsicContentSize()
    }
    
    
    public final func computeContentSizeThatFits() -> CGSize {
        return CGSize.sizeThatFits(containerSize: self.view.safeAreaLayoutGuide.layoutFrame.size, containedAR: 16.0/9.0)
    }
    
    override open func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate { _ in
            UIView.animate(withDuration: 0.25) {
                if size.width > size.height {
                    self.pgvcTop.isActive = false
                    self.pgvcTop = self.myContainerView.topAnchor.constraint(equalTo: self.scrollViewContent.safeAreaLayoutGuide.topAnchor)
                    self.pgvcTop.isActive = true
                } else {
                                        
                    self.pgvcTop.isActive = false
                    self.pgvcTop = self.myContainerView.topAnchor.constraint(equalTo: self.topbarView.view.bottomAnchor)
                    self.pgvcTop.isActive = true
                }
                
                self.pgvcHeight.isActive = false
                self.pgvcHeight = self.myContainerView.heightAnchor.constraint(equalToConstant: size.height)
                self.pgvcHeight.isActive = true
                
                self.pgvcWidth.isActive = false
                self.pgvcWidth = self.myContainerView.widthAnchor.constraint(equalToConstant: size.width)
                self.pgvcWidth.isActive = true
                
                if UIDevice.current.orientation.isValidInterfaceOrientation {
                    if UIDevice.current.orientation.isPortrait {
                        self.navigationItem.searchController = UISearchController(searchResultsController: ZTronSearchController())
                        self.navigationItem.searchController?.searchBar.placeholder = "Search Memory Charms"
                        self.navigationItem.searchController?.hidesNavigationBarDuringPresentation = false
                        self.topbarView.view.isHidden = false
                        self.bottomBarView.isHidden = false
                        self.captionView.isHidden = false
                        self.captionView.superview?.isHidden = false
                    } else {
                        self.navigationItem.searchController = nil
                        self.topbarView.view.isHidden = true
                        self.bottomBarView.isHidden = true
                        self.captionView.isHidden = true
                        self.captionView.superview?.isHidden = true
                    }
                    
                    self.view.layoutIfNeeded()
                }
            } completion: { @MainActor ended in
                self.view.layoutIfNeeded()
                self.updateScrollViewContentSize()
            }
        }
    }
    
    public final func updateScrollViewContentSize() {
        let contentHeight = self.scrollViewContent.subviews.reduce(0) { partialMaxHeight, subview in
            return max(partialMaxHeight, subview.frame.maxY)
        }
        
        self.wrappingScrollView.contentSize = CGSize(width: self.view.bounds.size.width, height: max(self.view.bounds.size.height, contentHeight))
        self.wrappingScrollView.frame = CGRect(
            origin: .init(x: self.view.safeAreaInsets.left, y: self.view.safeAreaInsets.top),
            size: .init(width: self.view.bounds.size.width, height: self.view.bounds.size.height)
        )
        
        self.scrollViewContent.frame = CGRect(
            origin: self.wrappingScrollView.frame.origin,
            size: .init(width: self.wrappingScrollView.bounds.size.width, height: max(self.view.bounds.size.height, contentHeight))
        )
        
        self.view.layoutIfNeeded()
    }
}

