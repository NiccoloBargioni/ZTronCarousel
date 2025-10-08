import UIKit
import ZTronObservation
import ZTronTheme

public final class CaptionOverlay: UIView, AnyCaptionView {
    public let displayStrategy: CaptionDisplayStrategy = .overlay
    public let id: String = "commander's caption"
    private var text: UILabel!
    nonisolated(unsafe) private var delegate: (any MSAInteractionsManager)? = nil {
        didSet {
            delegate?.setup(or: .replace)
        }
        
        willSet {
            delegate?.detach(or: .fail)
        }
    }
    
    private var theme: (any ZTronTheme) = ZTronThemeProvider.default().erasedToAnyTheme()
    
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        
        self.text = UILabel()
        self.text.font = UIFont.from(ztron: self.theme.erasedToAnyTheme(), font: \.uiSubheadline)
        self.text.textColor = .white
        
        self.text.text = ""
        self.text.translatesAutoresizingMaskIntoConstraints = false
        self.text.numberOfLines = 0
        self.text.textAlignment = .center
        
        self.addSubview(self.text)
        
        NSLayoutConstraint.activate([
            self.text.centerXAnchor.constraint(equalTo: self.safeAreaLayoutGuide.centerXAnchor),
            self.text.centerYAnchor.constraint(equalTo: self.safeAreaLayoutGuide.centerYAnchor),
            self.text.widthAnchor.constraint(lessThanOrEqualTo: self.safeAreaLayoutGuide.widthAnchor, multiplier: 0.75)
        ])
        
        self.text.setContentHuggingPriority(.required, for: .vertical)
        self.text.setContentHuggingPriority(.required, for: .horizontal)
        
        self.backgroundColor = UIColor.fromTheme(theme.colorSet, color: \.appBackgroundDark).withAlphaComponent(0.8)
    }
    
    required public init?(coder: NSCoder) {
        fatalError()
    }
    
    nonisolated public func setDelegate(_ interactionsManager: (any ZTronObservation.InteractionsManager)?) {
        guard let interactionsManager = (interactionsManager as? MSAInteractionsManager) else {
            if interactionsManager == nil {
                self.delegate = nil
            } else {
                fatalError("Expected interactions manager of type \(String(describing: MSAInteractionsManager.self)), in \(#function) @ \(#file)")
            }
            
            return
        }
        
        self.delegate = interactionsManager
    }

    public func setText(body: String) {
        self.text.text = body
        self.text.invalidateIntrinsicContentSize()
    }
    
    
    nonisolated public func getDelegate() -> (any ZTronObservation.InteractionsManager)? {
        return self.delegate
    }
    
    public func setTheme(_ theme: any ZTronTheme) {
        self.theme = theme
    }

}
