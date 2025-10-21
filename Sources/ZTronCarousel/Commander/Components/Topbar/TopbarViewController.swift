import UIKit
import SwiftUI
import ZTronTheme

public final class TopbarViewController: UIViewController {
    private let topbarModel: AnyTopbarViewModel
    private var topbarView: TopbarRouterView!
    private var theme: any ZTronTheme
    private let diameter: CGFloat
    
    private var makeViewForImage: (any TopbarComponent, UIAction, CGFloat) -> any AnyTopbarComponentView
    private var makeViewForLogo: (any TopbarComponent, UIAction, CGFloat) -> any AnyTopbarComponentView

    
    public init(
        model: TopbarModel, theme: any ZTronTheme = ZTronThemeProvider.default(),
        diameter: CGFloat = 40.0,
        makeViewForImage: @escaping (any TopbarComponent, UIAction, CGFloat) -> any AnyTopbarComponentView = { component, action, diameter in
            
            return TopbarComponentView(
                component: component,
                action: action,
                diameter: diameter,
            )
        },
        makeViewForLogo: @escaping (any TopbarComponent, UIAction, CGFloat) -> any AnyTopbarComponentView = { component, action, diameter in
            
            return AnonymousTopbarComponentView(
                component: component,
                action: action,
                diameter: diameter,
                fillBorders: false,
            )
        }
    ) {
        self.topbarModel = model
        self.theme = theme
        self.diameter = diameter
        
        self.makeViewForImage = makeViewForImage
        self.makeViewForLogo = makeViewForLogo
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        self.topbarView = .init(
            model: self.topbarModel,
            diameter: self.diameter,
            theme: self.theme,
            makeViewForImage: self.makeViewForImage,
            makeViewForLogo: self.makeViewForLogo
        )
        
        self.view.backgroundColor = UIColor.clear
        self.topbarView.backgroundColor = UIColor.clear
                
        self.view.addSubview(self.topbarView)
        self.topbarView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            self.topbarView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
            self.topbarView.leftAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leftAnchor),
            self.topbarView.rightAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.rightAnchor),
            self.topbarView.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor)
        ])
        
        self.topbarModel.onHideRequest {
            self.topbarView.collapse()
        }
        
        self.topbarModel.onShowRequest {
            self.topbarView.expand()
        }
    }
    
    override public func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate { _ in
            
        } completion: { _ in
            self.topbarView.viewDidTransition(to: size)
        }
    }
    
    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }
}

