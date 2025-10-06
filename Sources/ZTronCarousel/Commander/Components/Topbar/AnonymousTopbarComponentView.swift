import UIKit
import SwiftUI
import ZTronTheme

/// ```
/// logoView =
/// |------AvatarWrapper
/// |---------------|
/// |---------------|---------------Avatar
/// |---------------|-------------------|
/// |---------------|-------------------|---------IconShape
/// ```
public final class AnonymousTopbarComponentView: UIView, AnyTopbarComponentView {
    private var component: any TopbarComponent
    private var action: UIAction
    private let diameter: CGFloat
    weak private var logoView: UIView? = nil
    weak private var titleView: UILabel? = nil
    
    private var isActive: Bool = false
    private let theme: any ZTronTheme
    
    public init(
        component: any TopbarComponent,
        action: UIAction,
        diameter: CGFloat = 30.0,
        theme: any ZTronTheme = ZTronThemeProvider.default()
    ) {
        self.component = component
        self.action = action
        self.diameter = diameter
        self.theme = theme
        super.init(frame: .zero)
        
        self.backgroundColor = .clear

        setup()
    }
    
    public required init?(coder: NSCoder) {
        fatalError()
    }
    
    
    public final func setup() {
        let topbarComponentContainer: UIButton = .init(type: .system)
        topbarComponentContainer.addAction(self.action, for: .touchUpInside)

        self.addSubview(topbarComponentContainer)
        topbarComponentContainer.translatesAutoresizingMaskIntoConstraints = false
        
        
        let topbarComponentAvatar: UIView = .init(frame: .zero)
        let topbarComponentAvatarWrapper: UIView = .init(frame: .zero)
        
        topbarComponentAvatarWrapper.translatesAutoresizingMaskIntoConstraints = false
        topbarComponentAvatarWrapper.addSubview(topbarComponentAvatar)
        topbarComponentAvatarWrapper.backgroundColor = UIColor.fromTheme(self.theme.colorSet, color: \.appBackground)
        topbarComponentAvatarWrapper.isUserInteractionEnabled = false
        
        topbarComponentAvatar.layer.masksToBounds = true

        topbarComponentContainer.addSubview(topbarComponentAvatarWrapper)
        topbarComponentAvatar.translatesAutoresizingMaskIntoConstraints = false
        topbarComponentAvatar.layer.cornerRadius = self.diameter / 2.0
        topbarComponentAvatar.layer.backgroundColor = UIColor.fromTheme(self.theme.colorSet, color: \.disabled).withAlphaComponent(0.1).cgColor
        
        let title: UILabel = .init()
        title.text = self.component.getName()
        title.textColor = UIColor.fromTheme(self.theme.colorSet, color: \.disabled)
        title.numberOfLines = 0
        title.font = .systemFont(
            ofSize: 10,
            weight: .regular
        )
        
        
        title.textAlignment = .center
        title.lineBreakMode = .byWordWrapping
                    
        title.translatesAutoresizingMaskIntoConstraints = false
        
        topbarComponentContainer.addSubview(title)
        
        NSLayoutConstraint.activate([
            topbarComponentAvatarWrapper.widthAnchor.constraint(equalToConstant: self.diameter),
            topbarComponentAvatarWrapper.heightAnchor.constraint(equalTo: topbarComponentAvatarWrapper.widthAnchor),
            topbarComponentAvatarWrapper.centerXAnchor.constraint(equalTo: topbarComponentContainer.safeAreaLayoutGuide.centerXAnchor),

            topbarComponentAvatar.heightAnchor.constraint(equalTo: topbarComponentAvatarWrapper.heightAnchor),
            topbarComponentAvatar.widthAnchor.constraint(equalTo: topbarComponentAvatarWrapper.widthAnchor),
            topbarComponentAvatar.centerXAnchor.constraint(equalTo: topbarComponentAvatarWrapper.safeAreaLayoutGuide.centerXAnchor),
            topbarComponentAvatar.centerYAnchor.constraint(equalTo: topbarComponentAvatarWrapper.safeAreaLayoutGuide.centerYAnchor),
            
            topbarComponentContainer.topAnchor.constraint(equalTo: topbarComponentAvatarWrapper.topAnchor),
            topbarComponentContainer.widthAnchor.constraint(lessThanOrEqualToConstant: 80),
        ])

        
        NSLayoutConstraint.activate([
            topbarComponentContainer.bottomAnchor.constraint(greaterThanOrEqualTo: title.bottomAnchor),
            topbarComponentContainer.leftAnchor.constraint(lessThanOrEqualTo: title.leftAnchor),
            topbarComponentContainer.rightAnchor.constraint(greaterThanOrEqualTo: title.rightAnchor),
            
            title.topAnchor.constraint(equalTo: topbarComponentAvatarWrapper.bottomAnchor, constant: 5),
            title.centerXAnchor.constraint(equalTo: topbarComponentAvatarWrapper.centerXAnchor),
        ])
        
        self.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            self.topAnchor.constraint(equalTo: topbarComponentContainer.topAnchor),
            self.rightAnchor.constraint(equalTo: topbarComponentContainer.rightAnchor),
            self.bottomAnchor.constraint(equalTo: topbarComponentContainer.bottomAnchor),
            self.leftAnchor.constraint(equalTo: topbarComponentContainer.leftAnchor),
        ])

        
        topbarComponentAvatar.layer.zPosition = 2.0
        topbarComponentAvatarWrapper.layer.zPosition = 2.0
        topbarComponentContainer.layer.zPosition = 2.0
        self.layer.zPosition = 2.0
        
                
        self.logoView = topbarComponentAvatarWrapper
        self.titleView = title
    }
    
    public final func viewForLogo() -> UIView? {
        return self.logoView
    }
    
    public final func viewForTitle() -> UILabel? {
        return self.titleView
    }
    
    public final func makeActive() {
        guard let label = self.titleView else { return }
        
        label.animate(
            font: .systemFont(ofSize: 12, weight: .bold),
            textColor: .label,
            duration: 0.25
        )

        if let logoView = self.logoView {
            logoView.subviews[0].subviews.forEach { subview in
                subview.removeFromSuperview()
            }

            let eyeLayer = UIHostingController(rootView: EyeShape().fill(Color(self.theme.erasedToAnyTheme(), value: \.brand)))
            eyeLayer.view.backgroundColor = .clear
            
            logoView.subviews.first?.addSubview(eyeLayer.view)
            eyeLayer.view.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                eyeLayer.view.widthAnchor.constraint(equalToConstant: 0.6 * self.diameter),
                eyeLayer.view.heightAnchor.constraint(equalToConstant: self.diameter * 0.44),
                eyeLayer.view.centerXAnchor.constraint(equalTo: logoView.subviews.first!.centerXAnchor),
                eyeLayer.view.centerYAnchor.constraint(equalTo: logoView.subviews.first!.centerYAnchor),
            ])
            
            logoView.subviews.first?.layer.backgroundColor = UIColor.fromTheme(self.theme.colorSet, color: \.brand).withAlphaComponent(0.1).cgColor
        } else {
            fatalError()
        }
       
        self.isActive.toggle()
    }
    
    public final func makeVisited() {
        guard let label = self.titleView else { return }

        label.animate(
            font: .systemFont(ofSize: 10, weight: .regular),
            textColor: UIColor.fromTheme(self.theme.colorSet, color: \.disabled),
            duration: 0.25
        )

        if let logoView = self.logoView {
            logoView.subviews[0].subviews.forEach { subview in
                subview.removeFromSuperview()
            }
            
            let checkmarkLayer = UIHostingController(rootView: CheckmarkView().fill(Color(self.theme.erasedToAnyTheme(), value: \.brand)))
            checkmarkLayer.view.backgroundColor = UIColor.clear
            
            logoView.subviews.first?.addSubview(checkmarkLayer.view)
            checkmarkLayer.view.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                checkmarkLayer.view.widthAnchor.constraint(equalToConstant: self.diameter / 2.0),
                checkmarkLayer.view.heightAnchor.constraint(equalToConstant: 0.3 * self.diameter),
                checkmarkLayer.view.centerXAnchor.constraint(equalTo: logoView.centerXAnchor),
                checkmarkLayer.view.centerYAnchor.constraint(equalTo: logoView.centerYAnchor),
            ])
            
            logoView.subviews.first?.layer.backgroundColor = UIColor.fromTheme(self.theme.colorSet, color: \.brand).withAlphaComponent(0.1).cgColor
        } else {
            fatalError()
        }
        
        self.isActive = false
    }
    
    public final func makeUnvisited() {
        guard let label = self.titleView else { return }
        
        label.animate(
            font: .systemFont(ofSize: 10, weight: .regular),
            textColor: UIColor.fromTheme(self.theme.colorSet, color: \.disabled),
            duration: 0.25
        )

        if let logoView = self.logoView {
            logoView.subviews[0].removeAllSubviewsConstraints()
        }
        
        logoView?.subviews[0].layer.backgroundColor = UIColor.fromTheme(self.theme.colorSet, color: \.disabled).withAlphaComponent(0.1).cgColor

        self.isActive = false
    }
    
    public func replaceModel(with model: any TopbarComponent) {
        self.viewForTitle()?.text = "\(model.getName())"
        
        self.component = model
    }

}
