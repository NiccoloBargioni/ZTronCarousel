import UIKit
import SwiftUI

public final class BottomBarAction<S: SwiftUI.Shape>: UIView, ActiveTogglableView {
    private let action: () -> Void
    private let role: BottomBarActionRole
    private let icon: S
    private let disabledColor: UIColor = UIColor(red: 123.0/255.0, green: 123.0/255.0, blue: 123.0/255.0, alpha: 1.0)
    private var iconView: BottomBarActionIcon<S>!
    private var iconViewController: UIViewController!
    private let isStateful: Bool
    
    /// Retained (beyond the local variable `setup()` originally used) so that `setEnabled(_:mutedColor:)`
    /// can toggle its `isUserInteractionEnabled` after construction.
    private var theButton: UIDimmingBackgroundButton!
    
    public init(role: BottomBarActionRole, icon: S, isStateful: Bool = true, action: @escaping () -> Void) {
        self.icon = icon
        self.action = action
        self.role = role
        self.isStateful = isStateful
        super.init(frame: .zero)
        
        if case .variant(let variant) = role {
            self.accessibilityIdentifier = variant.getSlave()
        } else {
            self.accessibilityIdentifier = String(describing: self.role)
        }
    }
    
    public final func setup() {
        let theButton = UIDimmingBackgroundButton(type: .system)
        
        theButton.addAction(UIAction(title: String(describing: role)) { _ in
            self.action()
            
            /*
            if self.isStateful {
                self.toggleActive()
            }*/
        }, for: .touchUpInside)
                
        theButton.translatesAutoresizingMaskIntoConstraints = false
        
        let buttonIcon = UIHostingController(rootView: BottomBarActionIcon(
            shape: self.icon,
            isInitiallyActive: self.role == .outline || self.role == .boundingCircle
        ))
        
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
        
        self.iconViewController = buttonIcon
        
        self.addSubview(theButton)
        
        self.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            theButton.topAnchor.constraint(equalTo: self.safeAreaLayoutGuide.topAnchor),
            theButton.rightAnchor.constraint(equalTo: self.safeAreaLayoutGuide.rightAnchor),
            theButton.bottomAnchor.constraint(equalTo: self.safeAreaLayoutGuide.bottomAnchor),
            theButton.leftAnchor.constraint(equalTo: self.safeAreaLayoutGuide.leftAnchor),
        ])
        
        self.iconView = buttonIcon.rootView
        self.theButton = theButton
    }
    
    public required init?(coder: NSCoder) {
        fatalError()
    }
    
    
    public final func toggleActive() {
        guard self.isStateful else { return }
        
        self.iconView.toggleActive()
        self.iconViewController.view.invalidateIntrinsicContentSize()
        
        self.layoutIfNeeded()
    }
    
    public final func setActive(_ isActive: Bool) {
        guard self.isStateful else { return }
        
        self.iconView.setActive(isActive)
        self.iconViewController.view.invalidateIntrinsicContentSize()

        self.layoutIfNeeded()
    }
    
    // MARK: - TO SUPPORT MUTING UNAVAILABLE CONTENTS
    /// Unlike `toggleActive`/`setActive`, this isn't gated on `isStateful`: a non-stateful action
    /// (e.g. a future one-shot button) can still be muted when its content doesn't exist.
    public final func setEnabled(_ isEnabled: Bool, mutedColor: UIColor) {
        self.theButton?.isUserInteractionEnabled = isEnabled
        self.iconView.setEnabled(isEnabled, mutedColor: mutedColor)
        self.iconViewController.view.invalidateIntrinsicContentSize()
        
        self.layoutIfNeeded()
    }
}
