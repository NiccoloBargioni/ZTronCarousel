import ZTronObservation
import UIKit
import ZTronTheme

@MainActor public protocol AnyBottomBar: Component, AnyObject, UIView {
    @MainActor var lastAction: BottomBarLastAction { get }
    @MainActor var currentImage: String? { get }
    @MainActor var lastTappedVariantDescriptor: ImageVariantDescriptor? { get }

    
    @MainActor func switchVariants(_ to: [ImageVariantDescriptor], completion: ((_ completed: Bool) -> Void)?)
    @MainActor func appendGoBackVariant(icon: String?)
    @MainActor func clearVariantsStack(completion: ((Bool) -> Void)?)
    nonisolated func setCurrentImage(_ to: String)
    
    @MainActor func toggleActive(_ role: BottomBarActionRole)
    @MainActor func setActive(_ isActive: Bool, for role: BottomBarActionRole)
    
    // MARK: - TO SUPPORT MUTING UNAVAILABLE CONTENTS
    /// Enables or disables a content's bottom-bar action based on whether the current image
    /// actually has that content (as opposed to `setActive`, which reflects whether an *existing*
    /// content is currently toggled on). Disabled contents get `isUserInteractionEnabled = false`
    /// and are tinted with the theme's `disabled` color. `CarouselPageFromDB`'s bottom-bar
    /// interactions manager calls this on every page change, re-evaluating from scratch.
    @MainActor func setEnabled(_ isEnabled: Bool, for role: BottomBarActionRole)
    
    @MainActor func setTheme(_ theme: any ZTronTheme)
    
    // MARK: - TO SUPPORT PAYWALLING
    /// Injects the paywall gating this bar's contents, along with the view controller to present
    /// the paywall prompt from. `CarouselPageFromDB` invokes this after wiring the bar's
    /// interactions manager, and again whenever its paywall is replaced.
    @MainActor func setPaywall(_ paywall: (any CarouselPaywalling)?, presentingFrom host: UIViewController?)
}

public extension AnyBottomBar {
    /// Default no-op, so that existing custom bars keep compiling. Both `BottomBarView` and
    /// `UICarouselPageBottomBar` override this to suppress gated actions and present the paywall
    /// prompt in a bottom sheet.
    @MainActor func setPaywall(_ paywall: (any CarouselPaywalling)?, presentingFrom host: UIViewController?) {
        #if DEBUG
        if paywall != nil {
            print("\(String(describing: Self.self)) does not implement setPaywall(_:presentingFrom:): its contents will not be gated.")
        }
        #endif
    }
    
    /// Default no-op, so that existing custom bars keep compiling without adopting muting.
    @MainActor func setEnabled(_ isEnabled: Bool, for role: BottomBarActionRole) {
        #if DEBUG
        if !isEnabled {
            print("\(String(describing: Self.self)) does not implement setEnabled(_:for:): \(role) will keep appearing enabled even though the current image has no matching content.")
        }
        #endif
    }
}

public enum BottomBarLastAction: Equatable {
    case ready
    case toggleOutline
    case toggleBoundingCircle
    case tappedVariantChange(ImageVariantDescriptor)
    case tappedGoBack
    case tappedToggleCaption
    case tappedColorPicker
}
