import UIKit
import SwiftUI
import ZTronTheme

public final class TopbarViewController: UIViewController {
    private let topbarModel: TopbarModel
    private var topbarView: TopbarRouterView!
    private var theme: any ZTronTheme
    
    public init(model: TopbarModel, theme: any ZTronTheme = ZTronThemeProvider.default()) {
        self.topbarModel = model
        self.theme = theme
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        self.topbarView = .init(model: self.topbarModel, theme: self.theme)
        self.view.backgroundColor = UIColor.clear
                
        self.view.addSubview(self.topbarView)
        self.topbarView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            self.topbarView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
            self.topbarView.leftAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leftAnchor),
            self.topbarView.rightAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.rightAnchor),
            self.topbarView.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor)
        ])
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

