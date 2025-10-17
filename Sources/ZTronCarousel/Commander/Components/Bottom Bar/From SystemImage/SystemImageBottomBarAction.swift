import UIKit
import SwiftUI
import ZTronTheme

public final class SystemImageBottomBarAction: UIView, ActiveTogglableView {
    private let action: () -> Void
    private let role: BottomBarActionRole
    private let icon: String
    private let disabledColor: UIColor = UIColor(red: 123.0/255.0, green: 123.0/255.0, blue: 123.0/255.0, alpha: 1.0)
    private let isStateful: Bool
    private var isActive: Bool = true
    
    private var iconView: UIImageView!
    private var buttonView: UIButton!
    
    private let theme: any ZTronTheme
    
    public init(
        role: BottomBarActionRole,
        icon: String,
        isStateful: Bool = true,
        theme: any ZTronTheme = ZTronThemeProvider.default(),
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.action = action
        self.role = role
        self.isStateful = isStateful
        self.theme = theme
        super.init(frame: .zero)
        
        self.accessibilityIdentifier = String(describing: self.role)
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
        
        let buttonIcon = UIImageView(
            image:
                UIImage(systemName: self.icon)?
                    .withRenderingMode(.alwaysOriginal)
                    .withTintColor(UIColor.fromTheme(self.theme.colorSet, color: \.label))
                    .withConfiguration((UIImage.SymbolConfiguration(font: .systemFont(ofSize: 16), scale: .large)))
        )
        
        
        theButton.addSubview(buttonIcon)
        buttonIcon.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            buttonIcon.topAnchor.constraint(equalTo: theButton.safeAreaLayoutGuide.topAnchor),
            buttonIcon.rightAnchor.constraint(equalTo: theButton.safeAreaLayoutGuide.rightAnchor),
            buttonIcon.bottomAnchor.constraint(equalTo: theButton.safeAreaLayoutGuide.bottomAnchor),
            buttonIcon.leftAnchor.constraint(equalTo: theButton.safeAreaLayoutGuide.leftAnchor),
        ])
        
        theButton.setContentHuggingPriority(.required, for: .horizontal)
        
        buttonIcon.backgroundColor = .clear
        buttonIcon.isUserInteractionEnabled = false
        
        self.addSubview(theButton)
        
        self.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            theButton.topAnchor.constraint(equalTo: self.safeAreaLayoutGuide.topAnchor),
            theButton.rightAnchor.constraint(equalTo: self.safeAreaLayoutGuide.rightAnchor),
            theButton.bottomAnchor.constraint(equalTo: self.safeAreaLayoutGuide.bottomAnchor),
            theButton.leftAnchor.constraint(equalTo: self.safeAreaLayoutGuide.leftAnchor),
        ])
        
        self.buttonView = theButton
        self.iconView = buttonIcon
    }
    
    public required init?(coder: NSCoder) {
        fatalError()
    }
    
    
    public final func toggleActive() {
        guard self.isStateful else { return }
        self.isActive.toggle()
        
        self.layoutIfNeeded()
        self.iconView.image = self.iconView.image?.withTintColor(
            UIColor.fromTheme(
                self.theme.colorSet,
                color: self.isStateful ? self.isActive ? \.label : \.disabled : \.label
            )
        )
        self.layoutIfNeeded()
    }
    
    public final func setActive(_ isActive: Bool) {
        guard self.isStateful else { return }
        
        if self.isActive != isActive {
            self.toggleActive()
        }
    }
}
