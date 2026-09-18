import UIKit

/// Injects paywalling behavior into a carousel page: which bottom-bar contents are gated, whether
/// the paywall is currently in force, and what to present when the user taps a gated content.
///
/// When a bottom bar action maps (through `BottomBarActionRole.fromBottomBarAction(_:)`) to a role
/// for which ``shouldGate(_:)`` returns `true`, the whole effect of the action is suppressed: the
/// bar's `lastAction` is not mutated, the button does not toggle its active state, and no
/// notification reaches the mediator — so no downstream interactions manager reacts. In its place,
/// the view controller returned by ``makePaywallPrompt(for:)`` is presented inside a medium-detent
/// bottom sheet.
///
/// A paywall reaches a `CarouselPageFromDB` in two ways, in order of precedence:
/// 1. explicitly, through `CarouselPageFromDB.init(paywall:)` — this is what the SwiftUI
///    `.paywalled(_:isPaywalled:prompt:)` modifiers on `ZTronCarouselView` resolve to;
/// 2. as a default injected by the components factory via `ZTronComponentsFactory.makePaywall()`.
///
/// Conformers are `@MainActor` classes, and therefore implicitly `Sendable`.
@MainActor public protocol CarouselPaywalling: AnyObject, Sendable {
    /// Whether tapping `role` must be suppressed and replaced with the paywall prompt.
    ///
    /// This is re-evaluated on every tap: implementations typically resolve it as "the content is
    /// configured as gated AND the user has not purchased yet", so that completing a purchase
    /// unlocks the content immediately, without rebuilding the carousel.
    func shouldGate(_ role: BottomBarActionRole) -> Bool
    
    /// The view controller to present inside the bottom sheet when the user taps the gated `role`.
    /// Returning `nil` suppresses the action silently, with no sheet.
    func makePaywallPrompt(for role: BottomBarActionRole) -> UIViewController?
}
