import UIKit
import ZTronObservation
import SnapKit
@preconcurrency import Combine

public final class UICarouselPageBottomBar: UIView, Sendable, Component, AnyBottomBar {
    public let id: String = "bottom bar"
    
    private var borderLayer: CALayer? = nil
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
    
    private(set) public var lastAction: BottomBarLastAction = .ready
    private(set) public var currentImage: String? = nil
    
    private var variantsStack: UIStackView?
    private let throttler: PassthroughSubject<BottomBarLastAction, Never> = .init()
    private var cancellables: Set<AnyCancellable> = .init()
    
    private(set) public var lastTappedVariantDescriptor: ImageVariantDescriptor? = nil
    
    override public var bounds: CGRect {
        didSet {
            self.borderLayer?.removeFromSuperlayer()
            self.borderLayer = CALayer()
            
            
            borderLayer!.borderColor = UIColor.separator.cgColor
            borderLayer!.borderWidth = 0.3
            borderLayer!.frame = CGRect(x: 0, y: self.frame.size.height-0.3, width: self.frame.size.width, height: 0.3)
            
            
            self.layer.addSublayer(borderLayer!)
        }
    }
    
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.backgroundColor = UIColor(named: "BottomBar")
        
        
        let buttonsHStack = UIStackView(frame: frame)
        buttonsHStack.axis = .horizontal
        buttonsHStack.alignment = .center
        buttonsHStack.spacing = 8
                
        self.addSubview(buttonsHStack)
        
        buttonsHStack.snp.makeConstraints { make in
            // make.top.bottom.equalTo(self.safeAreaLayoutGuide)
            make.left.equalTo(self.safeAreaLayoutGuide).offset(12)
        }
        
        buttonsHStack.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        
        let outlineButton = UIButton(type: .system, primaryAction: .init(handler: { _ in
            self.throttler.send(.toggleOutline)
        }))
        
        outlineButton.setImage(UIImage(systemName: "pencil.and.outline")!
            .withRenderingMode(.alwaysOriginal)
            .withTintColor(UIColor.label)
            .withConfiguration(UIImage.SymbolConfiguration(font: .systemFont(ofSize: 16), scale: .large)), for: .normal
        )
        
        buttonsHStack.addArrangedSubview(outlineButton)
        
        outlineButton.snp.makeConstraints { make in
            make.width.equalTo(outlineButton.snp.height)
            make.height.equalTo(44)
        }
        
        let boundingCircleButton = UIButton(type: .system, primaryAction: .init(handler: { _ in
            self.throttler.send(.toggleBoundingCircle)
        }))
        
        boundingCircleButton.setImage(UIImage(systemName: "circle.dashed")!
            .withRenderingMode(.alwaysOriginal)
            .withTintColor(UIColor.label)
            .withConfiguration(UIImage.SymbolConfiguration(font: .systemFont(ofSize: 16), scale: .large)), for: .normal
        )
        
        buttonsHStack.addArrangedSubview(boundingCircleButton)
        
        boundingCircleButton.snp.makeConstraints { make in
            make.width.equalTo(boundingCircleButton.snp.height)
            make.height.equalTo(44)
        }
        
        
        let variantsStackView = UIStackView(frame: frame)
        variantsStackView.axis = .horizontal
        variantsStackView.alignment = .center
        variantsStackView.spacing = 8
        
        self.addSubview(variantsStackView)
        
        variantsStackView.snp.makeConstraints { make in
            make.right.equalTo(variantsStackView.superview!.safeAreaLayoutGuide).inset(12)
            make.left.greaterThanOrEqualTo(buttonsHStack.snp.right)
        }
        
        variantsStackView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        
        self.variantsStack = variantsStackView
        
        self.throttler.throttle(for: .seconds(0.5), scheduler: DispatchQueue.main, latest: true).sink { action in
            self.lastAction = action
            self.pushNotification()
        }
        .store(in: &self.cancellables)
    }
    
    required init(coder: NSCoder) {
        fatalError("Cannot int \(String(describing: Self.self)) from Storyboard")
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

    nonisolated public func setCurrentImage(_ to: String) {
        Task(priority: .userInitiated) { @MainActor in
            self.currentImage = to
        }
    }
    
    @MainActor public final func clearVariantsStack(completion: ((Bool) -> Void)? = nil) {
        if let variantsStack = self.variantsStack {
            UIView.animate(withDuration: 0.25) {
                variantsStack.subviews.forEach {
                    $0.alpha = 0.0
                }
            } completion: { didFinishAnimating in
                variantsStack.subviews.forEach {
                    variantsStack.removeArrangedSubview($0)
                    $0.removeFromSuperview()
                }
                completion?(didFinishAnimating)
            }
        }
    }
    
    @MainActor public final func appendGoBackVariant(icon: String?) {
        guard let theIcon = icon else { return }
        
        let goBack = UIButton(type: .system, primaryAction: .init(handler: { _ in
            self.lastAction = .tappedGoBack
            self.pushNotification()
        }))
        
        goBack.setImage(UIImage(systemName: theIcon)!
            .withRenderingMode(.alwaysOriginal)
            .withTintColor(UIColor.label)
            .withConfiguration(UIImage.SymbolConfiguration(font: .systemFont(ofSize: 16), scale: .large)), for: .normal
        )

        self.variantsStack?.addArrangedSubview(goBack)
        
        goBack.snp.makeConstraints { make in
            make.width.equalTo(goBack.snp.height)
            make.height.equalTo(44)
        }
    }
    
    @MainActor public final func switchVariants(_ to: [ImageVariantDescriptor], completion: ((_ completed: Bool) -> Void)? = nil) {
        guard to.count > 0 else { return }
        
        self.variantsStack?.subviews.forEach {
            ($0 as? UIButton)?.isEnabled = false
        }
        
        self.clearVariantsStack { _ in
            
            to.forEach { variantDescriptor in
                let variantButton = UIButton(type: .system, primaryAction: .init(handler: { _ in
                    self.lastAction = .tappedVariantChange
                    self.lastTappedVariantDescriptor = variantDescriptor
                    self.pushNotification()
                }))
                
                variantButton.setImage(UIImage(systemName: variantDescriptor.getBottomBarIcon())!
                    .withRenderingMode(.alwaysOriginal)
                    .withTintColor(UIColor.label)
                    .withConfiguration(UIImage.SymbolConfiguration(font: .systemFont(ofSize: 16), scale: .large)), for: .normal
                )

                variantButton.alpha = 0
                self.variantsStack?.addArrangedSubview(variantButton)
                
                variantButton.snp.makeConstraints { make in
                    make.width.equalTo(variantButton.snp.height)
                    make.height.equalTo(44)
                }
            }

            if let variantsStack = self.variantsStack {
                UIView.animate(withDuration: 0.25) {
                    variantsStack.subviews.forEach {
                        $0.alpha = 1.0
                    }
                } completion: { completed in
                    completion?(completed)
                }
            }
            
        }
    }
    
    public func pushNotification() {
        self.delegate?.pushNotification(eventArgs: .init(source: self), limitToNeighbours: true)
    }
    
    deinit {
        self.cancellables.forEach { $0.cancel() }
    }
    

}

