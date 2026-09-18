import SwiftUI
import UIKit
import ZTronCarouselCore
import ZTronObservation
import ZTronSerializable
import ZTronTheme

/// A SwiftUI wrapper around `CarouselPageFromDB` with declarative paywalling:
///
/// ```swift
/// ZTronCarouselView(
///     foreignKeys: foreignKeys,
///     componentsFactory: CommanderComponentsFactory()
/// )
/// .paywalled(.outline, isPaywalled: !store.hasProUnlocked) {
///     ProUpsellView()
/// }
/// .paywalled(all: [.boundingCircle, .anyVariant], isPaywalled: !store.hasProUnlocked) {
///     ProUpsellView()
/// }
/// ```
///
/// Every `.paywalled` call appends a ``PaywallRule``; when a bottom-bar content is tapped, the
/// *first* rule mentioning it decides whether it is gated and which view is shown in the bottom
/// sheet. Contents no rule mentions fall back to the paywall injected by the components factory
/// through `makePaywall()`, if any. Because each rule captures `isPaywalled` from SwiftUI state,
/// completing a purchase unlocks the contents on the next view update, without rebuilding the
/// underlying view controller.
///
/// > Note: The type is named `ZTronCarouselView` rather than `ZTronCarousel` because the latter is
/// > the module's own name: a top-level type shadowing its module makes every `ZTronCarousel.X`
/// > qualified reference ambiguous, in this package and in every client.
public struct ZTronCarouselView: UIViewControllerRepresentable {
    private let gallery: String?
    private let foreignKeys: SerializableGalleryForeignKeys
    private let pageFactory: (any MediaFactory)?
    private let componentsFactory: any ZTronComponentsFactory
    private let interactionsManagersFactory: (any ZTronInteractionsManagersFactory)?
    private let theme: any ZTronTheme
    
    private var paywallRules: [PaywallRule] = []
    private var componentRegistrations: [(lifecycle: MediatorRegistrationLifecycle, setup: @MainActor (MSAMediator) -> [any Component])] = []
    
    public init(
        gallery: String? = nil,
        foreignKeys: SerializableGalleryForeignKeys,
        with pageFactory: (any MediaFactory)? = nil,
        componentsFactory: any ZTronComponentsFactory,
        interactionsManagersFactory: (any ZTronInteractionsManagersFactory)? = nil,
        theme: any ZTronTheme = ZTronThemeProvider.default()
    ) {
        self.gallery = gallery
        self.foreignKeys = foreignKeys
        self.pageFactory = pageFactory
        self.componentsFactory = componentsFactory
        self.interactionsManagersFactory = interactionsManagersFactory
        self.theme = theme
    }
    
    public func makeUIViewController(context: Context) -> CarouselPageFromDB {
        let page = CarouselPageFromDB(
            gallery: self.gallery,
            foreignKeys: self.foreignKeys,
            with: self.pageFactory,
            componentsFactory: self.componentsFactory,
            interactionsManagersFactory: self.interactionsManagersFactory,
            theme: self.theme,
            paywall: self.makeResolvedPaywall()
        )
        
        for registration in self.componentRegistrations {
            page.registerComponents(lifecycle: registration.lifecycle, registration.setup)
        }
        
        return page
    }
    
    public func updateUIViewController(_ uiViewController: CarouselPageFromDB, context: Context) {
        if let composite = uiViewController.paywall as? CompositeCarouselPaywall {
            composite.setRules(self.paywallRules)
        } else if !self.paywallRules.isEmpty {
            uiViewController.setPaywall(self.makeResolvedPaywall())
        }
    }
    
    private func makeResolvedPaywall() -> (any CarouselPaywalling)? {
        guard !self.paywallRules.isEmpty else {
            // No explicit rule: CarouselPageFromDB falls back to componentsFactory.makePaywall() on its own.
            return nil
        }
        
        return CompositeCarouselPaywall(
            rules: self.paywallRules,
            fallback: self.componentsFactory.makePaywall()
        )
    }
    
    // MARK: - External components
    
    /// Registers client components in the page's mediator, alongside the built-in ones. The setup
    /// closure receives the mediator; it must create the components, wire each one's interactions
    /// manager via `setDelegate(_:)` (which registers it), and return what it registered so the
    /// page can manage retention and teardown.
    ///
    /// With `.media`, the closure runs every time a new image appears and its components are torn
    /// down when that image leaves the screen; with `.page` (the default), it runs once and its
    /// components persist until the page is dismissed.
    ///
    /// Registrations are applied when the underlying view controller is created; appending or
    /// removing registrations across SwiftUI updates has no effect on an already-live page.
    public func registerComponents(
        lifecycle: MediatorRegistrationLifecycle = .page,
        _ setup: @escaping @MainActor (MSAMediator) -> [any Component]
    ) -> ZTronCarouselView {
        var copy = self
        copy.componentRegistrations.append((lifecycle: lifecycle, setup: setup))
        return copy
    }
    
    // MARK: - Paywall modifiers
    
    /// Locks a single content behind the paywall, presenting `prompt` in a bottom sheet whenever it
    /// is tapped while `isPaywalled` is `true`.
    public func paywalled<Prompt: View>(
        _ content: PaywalledContent,
        isPaywalled: Bool,
        @ViewBuilder prompt: @escaping () -> Prompt
    ) -> ZTronCarouselView {
        return self.paywalled(all: [content], isPaywalled: isPaywalled, prompt: prompt)
    }
    
    /// Locks a set of contents behind the paywall with a shared prompt.
    public func paywalled<Prompt: View>(
        all contents: Set<PaywalledContent>,
        isPaywalled: Bool,
        @ViewBuilder prompt: @escaping () -> Prompt
    ) -> ZTronCarouselView {
        var copy = self
        
        copy.paywallRules.append(
            PaywallRule(contents: contents, isPaywalled: isPaywalled) { _ in
                return UIHostingController(rootView: prompt())
            }
        )
        
        return copy
    }
    
    /// Locks a single content behind the paywall, using the library's default prompt.
    public func paywalled(_ content: PaywalledContent, isPaywalled: Bool) -> ZTronCarouselView {
        return self.paywalled(all: [content], isPaywalled: isPaywalled)
    }
    
    /// Locks a set of contents behind the paywall, using the library's default prompt.
    public func paywalled(all contents: Set<PaywalledContent>, isPaywalled: Bool) -> ZTronCarouselView {
        var copy = self
        
        copy.paywallRules.append(
            PaywallRule(contents: contents, isPaywalled: isPaywalled) { _ in
                return DefaultPaywallPromptViewController(
                    title: "Contenuto bloccato".fromLocalized(),
                    message: "Sblocca questa funzionalità con l'acquisto.".fromLocalized(),
                    purchaseButtonTitle: "Scopri di più".fromLocalized()
                )
            }
        )
        
        return copy
    }
}
