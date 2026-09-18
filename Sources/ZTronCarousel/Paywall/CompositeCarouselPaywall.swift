import UIKit

/// A single paywalling rule: a set of contents, whether they are currently locked, and the prompt
/// shown when one of them is tapped. This is the unit accumulated by the SwiftUI
/// `.paywalled(_:isPaywalled:prompt:)` modifiers of `ZTronCarouselView`.
public struct PaywallRule: Sendable {
    public let contents: Set<PaywalledContent>
    public let isPaywalled: Bool
    public let prompt: @MainActor (BottomBarActionRole) -> UIViewController?
    
    public init(
        contents: Set<PaywalledContent>,
        isPaywalled: Bool,
        prompt: @escaping @MainActor (BottomBarActionRole) -> UIViewController?
    ) {
        self.contents = contents
        self.isPaywalled = isPaywalled
        self.prompt = prompt
    }
}

/// Combines an ordered list of ``PaywallRule``s with an optional fallback provider.
///
/// A role is resolved by the **first rule that mentions it**: that rule alone decides both the
/// gating (through its `isPaywalled` flag) and the prompt. Roles no rule mentions are delegated to
/// `fallback` — typically the default paywall injected by the components factory — so explicit
/// rules override the injected defaults content-by-content rather than wholesale.
@MainActor public final class CompositeCarouselPaywall: CarouselPaywalling {
    private(set) public var rules: [PaywallRule]
    private let fallback: (any CarouselPaywalling)?
    
    public init(rules: [PaywallRule], fallback: (any CarouselPaywalling)? = nil) {
        self.rules = rules
        self.fallback = fallback
    }
    
    /// Replaces the rules wholesale. `ZTronCarouselView` uses this on every SwiftUI update to
    /// propagate `isPaywalled` state changes into the existing view controller.
    public func setRules(_ rules: [PaywallRule]) {
        self.rules = rules
    }
    
    public func shouldGate(_ role: BottomBarActionRole) -> Bool {
        if let rule = self.firstRule(mentioning: role) {
            return rule.isPaywalled
        }
        
        return self.fallback?.shouldGate(role) ?? false
    }
    
    public func makePaywallPrompt(for role: BottomBarActionRole) -> UIViewController? {
        if let rule = self.firstRule(mentioning: role) {
            return rule.prompt(role)
        }
        
        return self.fallback?.makePaywallPrompt(for: role)
    }
    
    private func firstRule(mentioning role: BottomBarActionRole) -> PaywallRule? {
        return self.rules.first { $0.contents.matches(role) }
    }
}
