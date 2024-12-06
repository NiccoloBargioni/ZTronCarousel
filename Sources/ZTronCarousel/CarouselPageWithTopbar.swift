import UIKit
import SnapKit
import SwiftUI

import ZTronSerializable
import ZTronCarouselCore
import ZTronObservation

@MainActor open class CarouselPageWithTopbar: IOS15LayoutLimitingViewController {
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
    private(set) public var scrollView: UIScrollView = .init()
    
    // this will be used to change the page view controller height based on
    //    view width-to-height (portrait/landscape)
    // I know this could be done with a SnapKit object, but I don't use SnapKit...
    private var pgvcHeight: NSLayoutConstraint!
    private var pgvcWidth: NSLayoutConstraint!
    private var pgvcTop: NSLayoutConstraint!
    private var topbarWidth: NSLayoutConstraint!
    
    private var scrollViewTopContentGuide: NSLayoutConstraint!
    private var scrollViewBottomContentGuide: NSLayoutConstraint!
    
    // track current view width
    private var curWidth: CGFloat = 0.0
    
    private(set) public var bottomBarView: (any AnyBottomBar)!
    private(set) public var captionView: (any AnyCaptionView)!
        
    public let mediator: MSAMediator = .init()
    public let topbarView: UIViewController
    
    private var limitViewDidLayoutCalls: Int = Int.max
    
    public var isPortrait: Bool {
        if UIDevice.current.orientation.isValidInterfaceOrientation {
            return UIDevice.current.orientation.isPortrait
        } else {
            let scenes = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
            let keyWindow = scenes.first(where: { $0.keyWindow != nil })?.keyWindow ?? scenes.first?.keyWindow

            if let keyWindowBounds = keyWindow?.screen.bounds {
                return keyWindowBounds.height > keyWindowBounds.width
            } else {
                fatalError("Unable to infer initial device orientation")
            }
        }
    }
    
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
        
        var isPortrait = false
        
        if UIDevice.current.orientation.isValidInterfaceOrientation {
            isPortrait = UIDevice.current.orientation.isPortrait
        } else {
            let scenes = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
            let keyWindow = scenes.first(where: { $0.keyWindow != nil })?.keyWindow ?? scenes.first?.keyWindow

            if let keyWindowBounds = keyWindow?.screen.bounds {
                isPortrait = keyWindowBounds.height > keyWindowBounds.width
            } else {
                fatalError("Unable to infer initial device orientation")
            }
        }

        
        self.navigationItem.title = "Memory Charms"
        
        // so we can see the view / page view controller framing
        view.backgroundColor = .systemBackground
        
        self.view.addSubview(self.scrollView)
        self.scrollView.translatesAutoresizingMaskIntoConstraints = false
        self.scrollView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor).isActive = true
        self.scrollView.rightAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.rightAnchor).isActive = true
        self.scrollView.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor).isActive = true
        self.scrollView.leftAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leftAnchor).isActive = true
        
        self.scrollView.layer.zPosition = 2.0
        
        self.topbarView.willMove(toParent: self)
        self.addChild(self.topbarView)
        self.scrollView.addSubview(self.topbarView.view)
                
        self.topbarView.view.snp.makeConstraints { make in
            make.left.right.top.equalTo(self.scrollView.contentLayoutGuide)
            make.height.equalTo(self.topbarView.view.intrinsicContentSize.height)
        }
        
        if !self.isPortrait {
            self.topbarView.view.isHidden = true
        } else {
            self.topbarView.view.isHidden = false
        }
                
        self.topbarView.view.setContentHuggingPriority(.defaultHigh, for: .vertical)
        self.topbarView.view.layer.zPosition = 3.0

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
        
        // add the page VC's view to our container view
        myContainerView.addSubview(thePageVC.view)
        
        thePageVC.view.snp.makeConstraints { make in
            make.left.top.right.bottom.equalTo(thePageVC.view.superview!.safeAreaLayoutGuide)
        }
        
        self.bottomBarView = componentsFactory.makeBottomBar()
        self.bottomBarView.layer.zPosition = 3.0
        
        self.scrollView.addSubview(self.bottomBarView)

        self.bottomBarView.snp.makeConstraints { make in
            make.left.right.equalTo(thePageVC.view)
            make.top.equalTo(thePageVC.view.snp.bottom).offset(5)
            make.height.equalTo(44)
        }
        
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
        
        captionViewContainer.setContentHuggingPriority(.defaultHigh, for: .vertical)
        
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
        
        scrollViewBottomContentGuide = self.scrollView.contentLayoutGuide.bottomAnchor.constraint(
            equalTo: isPortrait ?
                self.captionView.safeAreaLayoutGuide.bottomAnchor :
                self.myContainerView.safeAreaLayoutGuide.bottomAnchor
            )

        self.scrollViewBottomContentGuide.isActive = true
        self.scrollViewTopContentGuide = self.scrollView.contentLayoutGuide.topAnchor.constraint(
            equalTo: isPortrait ?
                self.topbarView.view.safeAreaLayoutGuide.topAnchor :
                self.myContainerView.safeAreaLayoutGuide.topAnchor
        )
        self.scrollViewTopContentGuide.isActive = true
        
        self.scrollView.contentLayoutGuide.leftAnchor.constraint(equalTo: self.scrollView.frameLayoutGuide.leftAnchor).isActive = true
        self.scrollView.contentLayoutGuide.rightAnchor.constraint(equalTo: self.scrollView.frameLayoutGuide.rightAnchor).isActive = true
    }
    
    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if #unavailable(iOS 16.0) {
            guard self.limitViewDidLayoutCalls > 0 else { return }
            
            self.limitViewDidLayoutCalls -= 1
        }
                
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
    }
    
    
    public final func computeContentSizeThatFits() -> CGSize {
        return CGSize.sizeThatFits(containerSize: self.view.safeAreaLayoutGuide.layoutFrame.size, containedAR: 16.0/9.0)
    }
    
    override open func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        if #unavailable(iOS 16) {
            self.limitViewDidLayoutCalls = 1
        }
        
        coordinator.animate { _ in
            UIView.animate(withDuration: 0.25) {
                if size.width > size.height {
                    self.pgvcTop.isActive = false
                    self.pgvcTop = self.myContainerView.topAnchor.constraint(equalTo: self.scrollView.contentLayoutGuide.topAnchor)
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
                
                if size.width < size.height {
                    self.navigationItem.searchController = UISearchController(searchResultsController: ZTronSearchController())
                    self.navigationItem.searchController?.searchBar.placeholder = "Search Memory Charms"
                    self.navigationItem.searchController?.hidesNavigationBarDuringPresentation = false
                    self.topbarView.view.isHidden = false
                    self.bottomBarView.isHidden = false
                    self.captionView.isHidden = false
                    self.captionView.superview?.isHidden = false
                    
                    self.scrollViewTopContentGuide.isActive = false
                    self.scrollViewTopContentGuide = self.scrollView.contentLayoutGuide.topAnchor.constraint(equalTo: self.topbarView.view.safeAreaLayoutGuide.topAnchor)
                    self.scrollViewTopContentGuide.isActive = true
                    
                    self.updateScrollViewContentBottom(constraint: &self.scrollViewBottomContentGuide)
                } else {
                    self.navigationItem.searchController = nil
                    self.topbarView.view.isHidden = true
                    self.bottomBarView.isHidden = true
                    self.captionView.isHidden = true
                    self.captionView.superview?.isHidden = true
                    
                    /*
                    self.scrollViewTopContentGuide.isActive = false
                    self.scrollViewTopContentGuide = self.scrollView.contentLayoutGuide.topAnchor.constraint(equalTo: self.thePageVC.view.safeAreaLayoutGuide.topAnchor)
                    self.scrollViewTopContentGuide.isActive = true
                     */
                    self.updateScrollViewContentBottom(constraint: &self.scrollViewBottomContentGuide)
                }
                    
                self.view.layoutIfNeeded()
                
            } completion: { @MainActor ended in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    if #unavailable(iOS 16) {
                        self.limitViewDidLayoutCalls = Int.max
                    }
                    
                    self.topbarView.view.invalidateIntrinsicContentSize()
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
}

