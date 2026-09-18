import UIKit

/// The single interception point shared by the bottom bar implementations.
///
/// Both `BottomBarView` and `UICarouselPageBottomBar` funnel every button tap through a throttled
/// action sink; calling ``intercept(_:from:)`` as the first statement of that sink suppresses gated
/// actions *before* `lastAction` is mutated, before the tapped button toggles its active state, and
/// before any notification reaches the mediator — presenting the paywall prompt in a bottom sheet
/// instead. This is what guarantees that a gated tap has literally no side effect on the carousel.
@MainActor public final class PaywallGate {
    public var paywall: (any CarouselPaywalling)? = nil
    public weak var host: UIViewController? = nil
    
    public init() {  }
    
    /// - Parameters:
    ///   - action: The raw action emitted by the bar's throttler.
    ///   - sourceView: The bar itself; used to walk the responder chain toward a presenting view
    ///     controller when no explicit `host` was provided.
    /// - Returns: `true` when the action was gated (and the prompt, if any, presented): the caller
    ///   must `return` immediately, without processing the action any further.
    public func intercept(_ action: BottomBarLastAction, from sourceView: UIView) -> Bool {
        guard let paywall = self.paywall else { return false }
        guard let role = BottomBarActionRole.fromBottomBarAction(action) else { return false }
        guard paywall.shouldGate(role) else { return false }
        
        if let prompt = paywall.makePaywallPrompt(for: role) {
            PaywallSheetPresenter.present(prompt, from: sourceView, host: self.host)
        }
        
        return true
    }
}
