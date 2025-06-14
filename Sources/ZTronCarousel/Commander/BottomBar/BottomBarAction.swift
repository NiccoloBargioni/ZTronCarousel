import UIKit
import SwiftUI

public final class BottomBarAction<S: SwiftUI.Shape>: UIView {
    private let action: () -> Void
    private let title: String
    private let icon: S
    private let disabledColor: UIColor = UIColor(red: 123.0/255.0, green: 123.0/255.0, blue: 123.0/255.0, alpha: 1.0)
    private var iconView: BottomBarActionIcon<S>!
    
    
    public init(title: String, icon: S, action: @escaping () -> Void) {
        self.icon = icon
        self.action = action
        self.title = title
        super.init(frame: .zero)
    }
    
    public final func setup() {
        let theButton = UIDimmingBackgroundButton(type: .system)
        theButton.addAction(UIAction(title: self.title) { _ in
            self.action()
            self.toggleActive()
        }, for: .touchUpInside)
                
        theButton.translatesAutoresizingMaskIntoConstraints = false
        
        let buttonIcon = UIHostingController(rootView: BottomBarActionIcon(shape: self.icon))
        
        if #available(iOS 16, *) {
            buttonIcon.sizingOptions = .intrinsicContentSize
        }
        
        theButton.addSubview(buttonIcon.view)
        buttonIcon.view.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            buttonIcon.view.topAnchor.constraint(equalTo: theButton.safeAreaLayoutGuide.topAnchor),
            buttonIcon.view.rightAnchor.constraint(equalTo: theButton.safeAreaLayoutGuide.rightAnchor),
            buttonIcon.view.bottomAnchor.constraint(equalTo: theButton.safeAreaLayoutGuide.bottomAnchor),
            buttonIcon.view.leftAnchor.constraint(equalTo: theButton.safeAreaLayoutGuide.leftAnchor),
        ])
        
        buttonIcon.view.backgroundColor = .clear
        buttonIcon.view.isUserInteractionEnabled = false
        
        self.addSubview(theButton)
        
        self.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            theButton.topAnchor.constraint(equalTo: self.safeAreaLayoutGuide.topAnchor),
            theButton.rightAnchor.constraint(equalTo: self.safeAreaLayoutGuide.rightAnchor),
            theButton.bottomAnchor.constraint(equalTo: self.safeAreaLayoutGuide.bottomAnchor),
            theButton.leftAnchor.constraint(equalTo: self.safeAreaLayoutGuide.leftAnchor),
        ])
        
        self.iconView = buttonIcon.rootView
    }
    
    public required init?(coder: NSCoder) {
        fatalError()
    }
    
    
    public final func toggleActive() {
        self.iconView.toggleActive()
    }
}
