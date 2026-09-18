import UIKit
import SwiftUI

/// The standard ``CarouselPaywalling`` implementation: a static set of gated contents, a dynamic
/// `isPaywalled` resolver (typically backed by StoreKit entitlements), and a prompt factory.
///
/// ```swift
/// let paywall = DefaultCarouselPaywall(
///     gating: [.outline, .boundingCircle],
///     isPaywalled: { !PurchasesManager.shared.hasProUnlocked }
/// ) { _ in
///     UIHostingController(rootView: ProUpsellView())
/// }
/// ```
///
/// This is the natural type to return from `ZTronComponentsFactory.makePaywall()` to inject a
/// default paywall into every carousel built by that factory.
@MainActor public final class DefaultCarouselPaywall: CarouselPaywalling {
    private let gatedContent: Set<PaywalledContent>
    private let isPaywalled: () -> Bool
    private let promptFactory: (BottomBarActionRole) -> UIViewController?
    
    /// - Parameters:
    ///   - gatedContent: The contents locked behind the paywall.
    ///   - isPaywalled: Re-evaluated on every tap of a gated content; return `false` once the user
    ///     has purchased to unlock everything without rebuilding the carousel.
    ///   - promptFactory: Builds the view controller presented inside the bottom sheet. The tapped
    ///     role is provided, so the prompt can be specialized per-content.
    public init(
        gating gatedContent: Set<PaywalledContent>,
        isPaywalled: @escaping () -> Bool,
        prompt promptFactory: @escaping (BottomBarActionRole) -> UIViewController?
    ) {
        self.gatedContent = gatedContent
        self.isPaywalled = isPaywalled
        self.promptFactory = promptFactory
    }
    
    /// Convenience initializer that builds the prompt from a SwiftUI view.
    public convenience init<Prompt: View>(
        gating gatedContent: Set<PaywalledContent>,
        isPaywalled: @escaping () -> Bool,
        @ViewBuilder prompt: @escaping () -> Prompt
    ) {
        self.init(gating: gatedContent, isPaywalled: isPaywalled) { _ in
            return UIHostingController(rootView: prompt())
        }
    }
    
    /// Convenience initializer that presents ``DefaultPaywallPromptViewController`` with the
    /// provided texts.
    public convenience init(
        gating gatedContent: Set<PaywalledContent>,
        isPaywalled: @escaping () -> Bool,
        promptTitle: String = "Contenuto bloccato".fromLocalized(),
        promptMessage: String = "Sblocca questa funzionalità con l'acquisto.".fromLocalized(),
        purchaseButtonTitle: String = "Scopri di più".fromLocalized(),
        onPurchaseRequested: (() -> Void)? = nil
    ) {
        self.init(gating: gatedContent, isPaywalled: isPaywalled) { _ in
            return DefaultPaywallPromptViewController(
                title: promptTitle,
                message: promptMessage,
                purchaseButtonTitle: purchaseButtonTitle,
                onPurchaseRequested: onPurchaseRequested
            )
        }
    }
    
    public func shouldGate(_ role: BottomBarActionRole) -> Bool {
        return self.isPaywalled() && self.gatedContent.matches(role)
    }
    
    public func makePaywallPrompt(for role: BottomBarActionRole) -> UIViewController? {
        return self.promptFactory(role)
    }
}
