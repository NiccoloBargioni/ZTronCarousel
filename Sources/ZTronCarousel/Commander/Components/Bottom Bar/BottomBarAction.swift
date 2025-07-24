import UIKit
import SwiftUI

public final class BottomBarAction<S: SwiftUI.Shape>: UIView, ActiveTogglableView {
    private let action: () -> Void
    private let role: BottomBarActionRole
    private let icon: S?
    private let systemName: String?
    private let disabledColor: UIColor = UIColor(red: 123.0/255.0, green: 123.0/255.0, blue: 123.0/255.0, alpha: 1.0)
    private var iconView: BottomBarActionIcon<S>?
    private let isStateful: Bool
    
    public init(role: BottomBarActionRole, icon: S, isStateful: Bool = true, action: @escaping () -> Void) {
        self.icon = icon
        self.action = action
        self.role = role
        self.isStateful = isStateful
        self.systemName = nil
        super.init(frame: .zero)
        
        self.accessibilityIdentifier = self.role.rawValue
    }
        
    fileprivate init(
        role: BottomBarActionRole,
        systemName: String? = nil,
        icon: S? = EmptyShape(),
        isStateful: Bool = true,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.action = action
        self.role = role
        self.isStateful = isStateful
        self.systemName = nil
        super.init(frame: .zero)
        
        self.accessibilityIdentifier = self.role.rawValue
    }
        
    public final func setup() {
        let theButton = UIDimmingBackgroundButton(type: .system)
        assert(self.icon != nil || self.systemName != nil)
        
        theButton.addAction(UIAction(title: self.role.rawValue) { _ in
            self.action()
            
            /*
            if self.isStateful {
                self.toggleActive()
            }*/
        }, for: .touchUpInside)
                
        theButton.translatesAutoresizingMaskIntoConstraints = false
        
        if let icon = self.icon {
            let buttonIcon = UIHostingController(rootView: BottomBarActionIcon(shape: icon))
            
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
            
            self.iconView = buttonIcon.rootView
        } else {
            if let systemName = systemName {
                guard let iconView = UIImage(systemName: systemName)?
                    .withRenderingMode(.alwaysOriginal)
                    .withTintColor(.label)
                    .withConfiguration(UIImage.SymbolConfiguration(font: .systemFont(ofSize: 16), scale: .large)
                    ) else {
                    fatalError("Unable to make icon for system icon \(systemName)")
                }
                
                let iconImage = UIImageView(image: iconView)
                theButton.addSubview(iconImage)
                iconImage.translatesAutoresizingMaskIntoConstraints = false

                NSLayoutConstraint.activate([
                    iconImage.topAnchor.constraint(greaterThanOrEqualTo: theButton.safeAreaLayoutGuide.topAnchor),
                    iconImage.rightAnchor.constraint(equalTo: theButton.safeAreaLayoutGuide.rightAnchor),
                    iconImage.bottomAnchor.constraint(lessThanOrEqualTo: theButton.safeAreaLayoutGuide.bottomAnchor),
                    iconImage.leftAnchor.constraint(equalTo: theButton.safeAreaLayoutGuide.leftAnchor),
                ])
                
                iconImage.backgroundColor = .clear
                iconImage.isUserInteractionEnabled = false
                
                iconImage.setContentHuggingPriority(.required, for: .vertical)
                iconImage.setContentHuggingPriority(.required, for: .horizontal)
            }
            
        }

        self.addSubview(theButton)
        
        self.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            theButton.topAnchor.constraint(equalTo: self.safeAreaLayoutGuide.topAnchor),
            theButton.rightAnchor.constraint(equalTo: self.safeAreaLayoutGuide.rightAnchor),
            theButton.bottomAnchor.constraint(equalTo: self.safeAreaLayoutGuide.bottomAnchor),
            theButton.leftAnchor.constraint(equalTo: self.safeAreaLayoutGuide.leftAnchor),
        ])
        
    }
    
    public required init?(coder: NSCoder) {
        fatalError()
    }
    
    
    public final func toggleActive() {
        guard self.isStateful else { return }
        
        self.iconView?.toggleActive()
        self.layoutIfNeeded()
    }
    
    public final func setActive(_ isActive: Bool) {
        guard self.isStateful else { return }
        
        self.iconView?.setActive(isActive)
        self.layoutIfNeeded()
    }
}


internal extension BottomBarAction where S == EmptyShape {
    convenience init(
        role: BottomBarActionRole,
        systemName: String,
        isStateful: Bool = true,
        action: @escaping () -> Void
    ) {
        self.init(
            role: role,
            systemName: systemName,
            icon: nil,
            isStateful: isStateful,
            action: action
        )
    }

}

internal final class EmptyShape: Shape {
    func path(in rect: CGRect) -> Path {
        return Path()
    }
}
