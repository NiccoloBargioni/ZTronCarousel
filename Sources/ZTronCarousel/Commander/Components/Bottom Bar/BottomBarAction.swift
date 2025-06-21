import UIKit
import SwiftUI

public final class BottomBarAction<S: SwiftUI.Shape>: UIView, ActiveTogglableView {
    private let action: () -> Void
    private let role: BottomBarActionRole
    private let icon: S
    private let disabledColor: UIColor = UIColor(red: 123.0/255.0, green: 123.0/255.0, blue: 123.0/255.0, alpha: 1.0)
    private var iconView: BottomBarActionIcon<S>!
    private let isStateful: Bool
    
    public init(role: BottomBarActionRole, icon: S, isStateful: Bool = true, action: @escaping () -> Void) {
        self.icon = icon
        self.action = action
        self.role = role
        self.isStateful = isStateful
        super.init(frame: .zero)
        
        self.accessibilityIdentifier = self.role.rawValue
    }
    
    public final func setup() {
        let theButton = UIDimmingBackgroundButton(type: .system)
        
        theButton.addAction(UIAction(title: self.role.rawValue) { _ in
            self.action()
            
            /*
            if self.isStateful {
                self.toggleActive()
            }*/
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
        guard self.isStateful else { return }
        
        self.iconView.toggleActive()
        self.layoutIfNeeded()
    }
    
    public final func setActive(_ isActive: Bool) {
        guard self.isStateful else { return }
        
        self.iconView.setActive(isActive)
        self.layoutIfNeeded()
    }
}
