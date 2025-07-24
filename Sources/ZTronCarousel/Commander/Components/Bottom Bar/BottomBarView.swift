import UIKit
import SwiftUI
import ZTronObservation
import Combine
import ZTronTheme


public final class BottomBarView: UIView, Sendable, Component, AnyBottomBar {
    private(set) public var lastAction: BottomBarLastAction = .ready
    nonisolated(unsafe) private(set) public var currentImage: String? = nil
    private(set) public var lastTappedVariantDescriptor: ImageVariantDescriptor? = nil
    
    
    public let id: String = "Commander's Bottom Bar"
    private var theme: (any ZTronTheme)?
    
    private var brandColor: UIColor {
        if let theme = self.theme {
            return UIColor.fromTheme(theme.colorSet, color: \.brand)
        } else {
            return UIColor.fromTheme(ZTronThemeProvider.default().colorSet, color: \.brand)
        }
    }
    
    nonisolated(unsafe) private var delegate: (any MSAInteractionsManager)? = nil {
        willSet {
            guard let delegate = self.delegate else { return }
            delegate.detach(or: .ignore)
        }
        didSet {
            guard let delegate = self.delegate else { return }
            delegate.setup(or: .replace)
        }
    }
    
    private let throttler: PassthroughSubject<BottomBarLastAction, Never> = .init()
    nonisolated(unsafe) private var cancellables: Set<AnyCancellable> = .init()

    private let variantsStack: UIView! = .init(frame: .zero)

    override public init(frame: CGRect) {
        super.init(frame: frame)
        
        self.throttler.throttle(for: .seconds(0.5), scheduler: DispatchQueue.main, latest: true).sink { action in
            self.lastAction = action
            
            if let role = BottomBarActionRole.fromBottomBarAction(action) {
                self.toggleActive(role)
            }
            
            self.pushNotification()
        }
        .store(in: &self.cancellables)
        
        self.setup()
    }
    
    required public init?(coder: NSCoder) {
        return nil
    }
    
    public final func setup() {
        self.translatesAutoresizingMaskIntoConstraints = false
        let bottomBarView: UIView = .init()
        self.addSubview(bottomBarView)
        
        bottomBarView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            bottomBarView.topAnchor.constraint(equalTo: self.safeAreaLayoutGuide.topAnchor),
            bottomBarView.rightAnchor.constraint(equalTo: self.safeAreaLayoutGuide.rightAnchor),
            bottomBarView.leftAnchor.constraint(equalTo: self.safeAreaLayoutGuide.leftAnchor),
            bottomBarView.heightAnchor.constraint(greaterThanOrEqualToConstant: 39)
        ])
        
        self.variantsStack.translatesAutoresizingMaskIntoConstraints = false
        bottomBarView.addSubview(self.variantsStack)
        
        NSLayoutConstraint.activate([
            self.variantsStack.topAnchor.constraint(equalTo: bottomBarView.topAnchor),
            self.variantsStack.bottomAnchor.constraint(equalTo: bottomBarView.bottomAnchor),
        ])
        
        
        /*
        let currentImageIcon: UIImageView = .init(
            image: UIImage(systemName: "photo.fill")?
                .withRenderingMode(.alwaysOriginal)
                .withTintColor(self.brandColor)
                .withConfiguration(UIImage.SymbolConfiguration(font: .systemFont(ofSize: 18)))
        )
        
        bottomBarView.addSubview(currentImageIcon)
        currentImageIcon.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            currentImageIcon.heightAnchor.constraint(equalToConstant: 18),
            currentImageIcon.widthAnchor.constraint(equalTo: currentImageIcon.heightAnchor),
            currentImageIcon.centerYAnchor.constraint(equalTo: bottomBarView.centerYAnchor),
            currentImageIcon.leftAnchor.constraint(equalTo: bottomBarView.leftAnchor, constant: 20)
        ])
        
        let currentImageLabel = UILabel.init()
        currentImageLabel.text = "2 of 5"
        currentImageLabel.font = .systemFont(ofSize: 14)
        currentImageLabel.textColor = self.brandColor
        
        bottomBarView.addSubview(currentImageLabel)
        
        currentImageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            currentImageLabel.centerYAnchor.constraint(equalTo: currentImageIcon.centerYAnchor),
            currentImageLabel.leftAnchor.constraint(equalTo: currentImageIcon.rightAnchor, constant: 10),
        ])
        
        currentImageLabel.setContentHuggingPriority(.required, for: .vertical)
        currentImageLabel.setContentHuggingPriority(.required, for: .horizontal)
        */
        
        /*
        // MARK: - ZOOM
        let zoomButton = self.addAction(
            role: .fullScreen,
            icon: ZoomShape(),
            isStateful: false,
            rightAnchor: bottomBarView.rightAnchor,
            constant: -20
        ) {
            
        }
        */
        
        let boundingCircleButton = self.addAction(role: .boundingCircle, icon: BoundingCircleIcon(), rightAnchor: bottomBarView.rightAnchor, constant: -20) {
            self.throttler.send(.toggleBoundingCircle)
        }

        
        let outlineButton = self.addAction(role: .outline, icon: OutlineIcon(), rightAnchor: boundingCircleButton.leftAnchor, constant: -15) {
            self.throttler.send(.toggleOutline)
        }


        let separatorView: UIView = .init()
        bottomBarView.addSubview(separatorView)
        
        
        separatorView.backgroundColor = self.brandColor
        separatorView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            separatorView.centerYAnchor.constraint(equalTo: bottomBarView.safeAreaLayoutGuide.centerYAnchor),
            separatorView.heightAnchor.constraint(equalToConstant: 18),
            separatorView.widthAnchor.constraint(equalToConstant: 1),
            separatorView.rightAnchor.constraint(equalTo: outlineButton.leftAnchor, constant: -15)
        ])
        
        /*
        let triangulation = self.addAction(role: .triangulate, icon: TargetIcon(), rightAnchor: separatorView.leftAnchor, constant: -15) {
            print("Toggle triangulation")
        }

        let pickerAction = self.addAction(role: .colorPicker, icon: ColorPickerIcon(), rightAnchor: triangulation.leftAnchor, constant: -15) {
            
        }
        */
        
        let captionButton = self.addAction(role: .caption, icon: InfoShape(), rightAnchor: separatorView.leftAnchor, constant: -15) {
            self.throttler.send(.tappedToggleCaption)
        }
        
        
        
        NSLayoutConstraint.activate([
            self.safeAreaLayoutGuide.topAnchor.constraint(equalTo: bottomBarView.safeAreaLayoutGuide.topAnchor),
            self.safeAreaLayoutGuide.leftAnchor.constraint(equalTo: bottomBarView.safeAreaLayoutGuide.leftAnchor),
            self.safeAreaLayoutGuide.rightAnchor.constraint(equalTo: bottomBarView.safeAreaLayoutGuide.rightAnchor),
            self.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: bottomBarView.safeAreaLayoutGuide.bottomAnchor),
        ])
        
        let bottomDivider: UIView = .init()
        self.addSubview(bottomDivider)
        
        bottomDivider.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            bottomDivider.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            bottomDivider.heightAnchor.constraint(equalToConstant: 1.0),
            bottomDivider.leftAnchor.constraint(equalTo: self.leftAnchor),
            bottomDivider.rightAnchor.constraint(equalTo: self.rightAnchor),
        ])
        
        bottomDivider.backgroundColor = self.brandColor.withAlphaComponent(0.1)
        
        
        let zoomButton = self.addAction(role: .variant, systenName: "plus.magnifyingglass", rightAnchor: variantsStack.rightAnchor) {
            self.throttler.send(.toggleOutline)
        }

        self.variantsStack.addSubview(zoomButton)
        
        NSLayoutConstraint.activate([
            self.variantsStack.leftAnchor.constraint(equalTo: bottomBarView.leftAnchor),
            self.variantsStack.leftAnchor.constraint(equalTo: zoomButton.leftAnchor),
            self.variantsStack.rightAnchor.constraint(equalTo: zoomButton.rightAnchor),
        ])
        
    }
    
    @discardableResult internal final func addAction<S: SwiftUI.Shape>(
        role: BottomBarActionRole,
        icon: S,
        isStateful: Bool = true,
        rightAnchor: NSLayoutXAxisAnchor,
        constant: CGFloat = 0,
        action: @escaping () -> Void
    ) -> UIView {
        let action = BottomBarAction(role: role, icon: icon, isStateful: isStateful, action: action)
        
        if let bottomBarView = self.subviews.first {
            bottomBarView.addSubview(action)
            action.translatesAutoresizingMaskIntoConstraints = false
            action.setup()
            
            NSLayoutConstraint.activate([
                action.centerYAnchor.constraint(equalTo: bottomBarView.safeAreaLayoutGuide.centerYAnchor),
                action.rightAnchor.constraint(equalTo: rightAnchor, constant: constant)
            ])
            
            action.setContentHuggingPriority(.required, for: .vertical)

            
            NSLayoutConstraint.activate([
                self.safeAreaLayoutGuide.topAnchor.constraint(equalTo: bottomBarView.safeAreaLayoutGuide.topAnchor),
                self.safeAreaLayoutGuide.leftAnchor.constraint(equalTo: bottomBarView.safeAreaLayoutGuide.leftAnchor),
                self.safeAreaLayoutGuide.rightAnchor.constraint(equalTo: bottomBarView.safeAreaLayoutGuide.rightAnchor),
                self.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: bottomBarView.safeAreaLayoutGuide.bottomAnchor),
            ])
        }

        return action
    }
    
    
    @discardableResult internal final func addAction(
        role: BottomBarActionRole,
        systenName: String,
        isStateful: Bool = true,
        rightAnchor: NSLayoutXAxisAnchor,
        constant: CGFloat = 0,
        action: @escaping () -> Void
    ) -> UIView {
        let action = BottomBarAction(
            role: role,
            systemName: systenName,
            isStateful: isStateful,
            action: action
        )
        
        if let bottomBarView = self.subviews.first {
            bottomBarView.addSubview(action)
            action.translatesAutoresizingMaskIntoConstraints = false
            action.setup()
            
            NSLayoutConstraint.activate([
                action.centerYAnchor.constraint(equalTo: bottomBarView.safeAreaLayoutGuide.centerYAnchor),
                action.rightAnchor.constraint(equalTo: rightAnchor, constant: constant)
            ])
            
            action.setContentHuggingPriority(.required, for: .vertical)

            
            NSLayoutConstraint.activate([
                self.safeAreaLayoutGuide.topAnchor.constraint(equalTo: bottomBarView.safeAreaLayoutGuide.topAnchor),
                self.safeAreaLayoutGuide.leftAnchor.constraint(equalTo: bottomBarView.safeAreaLayoutGuide.leftAnchor),
                self.safeAreaLayoutGuide.rightAnchor.constraint(equalTo: bottomBarView.safeAreaLayoutGuide.rightAnchor),
                self.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: bottomBarView.safeAreaLayoutGuide.bottomAnchor),
            ])
        }

        return action
    }
    
    public func switchVariants(_ to: [ImageVariantDescriptor], completion: ((Bool) -> Void)?) {
        
    }
    
    public func appendGoBackVariant(icon: String?) {
        
    }
    
    public func clearVariantsStack(completion: ((Bool) -> Void)?) {
        
    }
    
    public func setCurrentImage(_ to: String) {
        self.currentImage = to
    }
    
    
    nonisolated public func getDelegate() -> (any ZTronObservation.InteractionsManager)? {
        return self.delegate
    }
    
    nonisolated public func setDelegate(_ interactionsManager: (any ZTronObservation.InteractionsManager)?) {
        guard let interactionsManager = (interactionsManager as? MSAInteractionsManager) else {
            if interactionsManager == nil {
                self.delegate = nil
            } else {
                fatalError("Expected interactions manager of type \(String(describing: MSAInteractionsManager.self)) in \(#function) at \(#file)")
            }
            
            return
        }
        
        self.delegate = interactionsManager
    }

    deinit {
        self.cancellables.forEach { $0.cancel() }
    }
    
    
    private final func buttonForRole(_ role: BottomBarActionRole) -> (any ActiveTogglableView)? {
        return self.subviews.first?.subviews.first {
            return $0.accessibilityIdentifier == role.rawValue
        } as? (any ActiveTogglableView)
    }
    
    
    public final func toggleActive(_ role: BottomBarActionRole) {
        guard let buttonForRole = self.buttonForRole(role) else { return }
        
        buttonForRole.toggleActive()
        self.subviews.first?.layoutIfNeeded()
    }
    
    public final func setActive(_ isActive: Bool, for role: BottomBarActionRole) {
        guard let buttonForRole = self.buttonForRole(role) else { return }

        buttonForRole.setActive(isActive)
        self.subviews.first?.layoutIfNeeded()
    }
    
    public final func setTheme(_ theme: any ZTronTheme) {
        self.theme = theme
    }

}

