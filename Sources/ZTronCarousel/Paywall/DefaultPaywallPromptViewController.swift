import UIKit

/// A minimal, ready-to-use paywall prompt: lock glyph, title, message and a call-to-action.
///
/// Meant as a sensible default for ``DefaultCarouselPaywall`` and for the promptless
/// `.paywalled(_:isPaywalled:)` SwiftUI modifiers; apps will typically provide their own
/// StoreKit-backed screen instead.
public final class DefaultPaywallPromptViewController: UIViewController {
    private let titleText: String
    private let messageText: String
    private let purchaseButtonTitle: String
    private let onPurchaseRequested: (() -> Void)?
    
    /// - Parameter onPurchaseRequested: Invoked after the sheet is dismissed when the user taps the
    ///   call-to-action. Hook the app's purchase flow (or a navigation to the store screen) here.
    public init(
        title: String,
        message: String,
        purchaseButtonTitle: String,
        onPurchaseRequested: (() -> Void)? = nil
    ) {
        self.titleText = title
        self.messageText = message
        self.purchaseButtonTitle = purchaseButtonTitle
        self.onPurchaseRequested = onPurchaseRequested
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        return nil
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = .systemBackground
        
        let lockImageView = UIImageView(
            image: UIImage(systemName: "lock.fill")?
                .withConfiguration(UIImage.SymbolConfiguration(pointSize: 42, weight: .semibold))
        )
        lockImageView.tintColor = .label
        lockImageView.contentMode = .scaleAspectFit
        
        let titleLabel = UILabel()
        titleLabel.text = self.titleText
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        
        let messageLabel = UILabel()
        messageLabel.text = self.messageText
        messageLabel.font = .preferredFont(forTextStyle: .body)
        messageLabel.textColor = .secondaryLabel
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        
        var buttonConfiguration = UIButton.Configuration.filled()
        buttonConfiguration.title = self.purchaseButtonTitle
        buttonConfiguration.cornerStyle = .large
        buttonConfiguration.buttonSize = .large
        
        let onPurchase = self.onPurchaseRequested
        let purchaseButton = UIButton(configuration: buttonConfiguration, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true) {
                onPurchase?()
            }
        })
        
        let stack = UIStackView(arrangedSubviews: [lockImageView, titleLabel, messageLabel, purchaseButton])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .fill
        stack.setCustomSpacing(24, after: messageLabel)
        
        self.view.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.centerYAnchor),
            stack.leftAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leftAnchor, constant: 32),
            stack.rightAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.rightAnchor, constant: -32),
            lockImageView.heightAnchor.constraint(equalToConstant: 56)
        ])
    }
}
