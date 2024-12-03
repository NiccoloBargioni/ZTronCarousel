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
    // private(set) public var thePageVC: CarouselComponent!
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
    
    private var limitDidLayoutSubviews: Int = Int.max
    private var limitWillLayoutSubviews: Int = Int.max
    private var limitMarginsWillChange: Int = Int.max
    
    
    public let mediator: MSAMediator = .init()
    public let topbarView: UIViewController
    
    public init(
        foreignKeys: SerializableGalleryForeignKeys,
        with pageFactory: (any MediaFactory)? = nil,
        componentsFactory: (any ZTronComponentsFactory)? = nil,
        interactionsManagersFactory: (any ZTronInteractionsManagersFactory)? = nil
    ) {
        print("LIFECYCLE \(#function)")
        self.componentsFactory = componentsFactory ?? DefaultZtronComponentsFactory()
        self.interactionsManagersFactory = interactionsManagersFactory ?? DefaultZTronInteractionsManagerFactory()
        
        self.carouselModel = self.componentsFactory.makeViewModel()
        self.dbLoader = self.componentsFactory.makeDBLoader(with: foreignKeys)
        
        self.pageFactory = pageFactory ?? BasicMediaFactory()
        self.thePageVC = CarouselComponent(with: self.pageFactory, medias: [])
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
        print("LIFECYCLE \(#function)")
        super.viewDidLoad()
        
        self.navigationItem.title = "Memory Charms"
        
        // so we can see the view / page view controller framing
        view.backgroundColor = .systemBackground
        
        self.topbarView.willMove(toParent: self)
        self.addChild(self.topbarView)
        self.view.addSubview(self.topbarView.view)
        
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
        myContainerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(myContainerView)
        
        myContainerView.snp.makeConstraints { make in
            make.centerX.equalTo(self.view.safeAreaLayoutGuide)
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
        
        // we need to re-size the page view controller's view to fit our container view
        thePageVC.view.translatesAutoresizingMaskIntoConstraints = false
        // thePageVC.translatesAutoresizingMaskIntoConstraints = false
        
        // add the page VC's view to our container view
        myContainerView.addSubview(thePageVC.view)
        // myContainerView.addSubview(thePageVC)
        
        thePageVC.view.snp.makeConstraints { make in
            make.left.top.right.bottom.equalTo(thePageVC.view.superview!.safeAreaLayoutGuide)
        }
        /*
        thePageVC.snp.makeConstraints { make in
            make.left.top.right.bottom.equalTo(thePageVC.superview!.safeAreaLayoutGuide)
        }*/
        
        self.bottomBarView = componentsFactory.makeBottomBar()
        
        self.view.addSubview(self.bottomBarView)

        self.bottomBarView.snp.makeConstraints { make in
            make.left.right.equalTo(thePageVC.view)
            make.top.equalTo(thePageVC.view.snp.bottom).offset(5)
            make.height.equalTo(44)
        }
        /*
        self.bottomBarView.snp.makeConstraints { make in
            make.left.right.equalTo(thePageVC)
            make.top.equalTo(thePageVC.snp.bottom).offset(5)
            make.height.equalTo(44)
        }*/
                
        self.bottomBarView.setDelegate(
            self.interactionsManagersFactory
                .makeBottomBarInteractionsManager(owner: self.bottomBarView, mediator: self.mediator)
        )
    
        self.captionView = componentsFactory.makeCaptionView()
        
        let captionViewContainer = BottomSeparatedUIView()
        self.view.addSubview(captionViewContainer)
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
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("LIFECYCLE \(#function)")
    }
    
    override open func viewWillLayoutSubviews() {
        print("LIFECYCLE \(#function)")
        guard self.limitWillLayoutSubviews > 0 else { return }

        super.viewWillLayoutSubviews()
        
        self.limitWillLayoutSubviews -= 1
    }
    
    
    override open func viewDidLayoutSubviews() {
        print("LIFECYCLE \(#function)")
        guard self.limitDidLayoutSubviews > 0 else { return }
        
        super.viewDidLayoutSubviews()
        
        self.limitDidLayoutSubviews -= 1
        // only execute this code block if the view frame has changed
        //    such as on device rotation
        if curWidth != myContainerView.frame.width {
            curWidth = myContainerView.frame.width
            
            // cannot directly change a constraint multiplier, so
            //    deactivate / create new / reactivate
            
            self.pgvcHeight.isActive = false
            self.pgvcWidth.isActive = false
            if myContainerView.superview!.frame.width / myContainerView.superview!.frame.height >= 16.0/9.0 {
                self.pgvcHeight = self.myContainerView.heightAnchor.constraint(equalTo: self.myContainerView.superview!.safeAreaLayoutGuide.heightAnchor)
                self.pgvcWidth = self.myContainerView.widthAnchor.constraint(equalTo: self.myContainerView.heightAnchor, multiplier: 16.0/9.0)
            } else {
                self.pgvcWidth = self.myContainerView.widthAnchor.constraint(equalTo: self.myContainerView.superview!.safeAreaLayoutGuide.widthAnchor)
                self.pgvcHeight = self.myContainerView.heightAnchor.constraint(equalTo: self.myContainerView.widthAnchor, multiplier: 9.0/16.0)
            }
            self.pgvcHeight.isActive = true
            self.pgvcWidth.isActive = true
        }
        
        self.topbarView.view.invalidateIntrinsicContentSize()
    }
    
    override public func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        print("LIFECYCLE \(#function)")
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("LIFECYCLE \(#function)")
    }
    
    override public func viewLayoutMarginsDidChange() {
        print("LIFECYCLE \(#function)")
        guard self.limitMarginsWillChange > 0 else { return }

        super.viewLayoutMarginsDidChange()
        
        self.limitMarginsWillChange -= 1
    }
    
    
    override public func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        print("LIFECYCLE \(#function)")
    }
    
    public final func computeContentSizeThatFits() -> CGSize {
        return CGSize.sizeThatFits(containerSize: self.view.safeAreaLayoutGuide.layoutFrame.size, containedAR: 16.0/9.0)
    }
    
    override open func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        print("LIFECYCLE \(#function)")
        
        self.limitDidLayoutSubviews = 1
        self.limitWillLayoutSubviews = 1
        self.limitMarginsWillChange = 1

        /*
        if #unavailable(iOS 16) {
            UIView.setAnimationsEnabled(false)
        }*/
        
        self.thePageVC.willMove(toParent: nil)
        self.thePageVC.removeFromParent()
        self.thePageVC.didMove(toParent: nil)
        coordinator.animate { _ in
            UIView.animate(withDuration: 0.25) {
                if size.width > size.height {
                    self.pgvcTop.isActive = false
                    self.pgvcTop = self.myContainerView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor)
                    self.pgvcTop.isActive = true
                } else {
                    
                    self.pgvcTop.isActive = false
                    self.pgvcTop = self.myContainerView.topAnchor.constraint(equalTo: self.topbarView.view.bottomAnchor)
                    self.pgvcTop.isActive = true
                }
                
                self.pgvcHeight.isActive = false
                self.pgvcWidth.isActive = false
                if size.width / size.height >= 16.0/9.0 {
                    self.pgvcHeight = self.myContainerView.heightAnchor.constraint(equalTo: self.myContainerView.superview!.safeAreaLayoutGuide.heightAnchor)
                    self.pgvcWidth = self.myContainerView.widthAnchor.constraint(equalTo: self.myContainerView.heightAnchor, multiplier: 16.0/9.0)
                } else {
                    self.pgvcWidth = self.myContainerView.widthAnchor.constraint(equalTo: self.myContainerView.superview!.safeAreaLayoutGuide.widthAnchor)
                    self.pgvcHeight = self.myContainerView.heightAnchor.constraint(equalTo: self.myContainerView.widthAnchor, multiplier: 9.0/16.0)
                }
                self.pgvcHeight.isActive = true
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
                }
                
                self.view.layoutIfNeeded()
            } completion: { @MainActor _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self.thePageVC.willMove(toParent: self)
                    self.addChild(self.thePageVC)
                    self.thePageVC.didMove(toParent: self)

                    
                    print("LIFECYCLE viewWillTransition(to:with:) completion")
                    self.limitDidLayoutSubviews = Int.max
                    self.limitWillLayoutSubviews = Int.max
                    self.limitWillLayoutSubviews = Int.max
                    
                    if #unavailable(iOS 16) {
                        UIView.setAnimationsEnabled(true)
                    }

                    self.view.setNeedsLayout()
                }
            }
        }
    }
    
    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        print("LIFECYCLE \(#function)")
    }
    
    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        print("LIFECYCLE \(#function)")
    }
}

