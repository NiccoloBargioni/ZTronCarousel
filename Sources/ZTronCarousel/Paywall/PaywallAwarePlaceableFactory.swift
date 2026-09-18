import UIKit
import ZTronObservation

/// Adopted by media factories (and anything else) that can consult a paywall while building their
/// output. `CarouselPageFromDB` detects the conformance on its page factory and injects a provider
/// that always reflects its current paywall — the same way it injects the mediator into
/// `Notifiable` factories. Deliberately mirrors `Notifiable`'s shape (a plain, non-isolated
/// protocol) so conformers can implement the requirement as `nonisolated`, exactly like
/// `setMediator(_:)`, regardless of whether the conformer itself is actor-isolated.
public protocol PaywallInjectable: AnyObject {
    func setPaywallProvider(_ provider: @escaping @MainActor () -> (any CarouselPaywalling)?)
}

/// A `ZTronPlaceableFactory` decorator that suppresses the *rendering* of paywalled features.
///
/// Gating a bottom-bar content only intercepts the tap; placeables, however, can be visible
/// without any tap because their `isActive` flag comes from the database. This decorator closes
/// that gap at the source: while `.outline` is gated, the outline's views (the `ZTronSVGView` and
/// its color picker) are simply never built — the page shows a blank overlay in their place — and
/// likewise for `.boundingCircle`. `.colorPicker` can also be gated on its own, dropping only the
/// picker while the outline stays.
///
/// Descriptors are never modified: the bottom bar and every interactions manager keep seeing the
/// full placeable metadata (which is what keeps the lock-badged buttons visible), only the views
/// are withheld. Since the corresponding views don't exist, their interactions managers are never
/// registered either, so no toggle can reach them by any path.
///
/// The paywall is read through a provider closure at page-construction time, so pages built after
/// a purchase come out un-gated with no reconfiguration; `CarouselPageFromDB.setPaywall(_:)`
/// additionally rebuilds the visible page so the change is immediate.
@MainActor public final class PaywallAwarePlaceableFactory: ZTronPlaceableFactory {
    private let wrapped: any ZTronPlaceableFactory
    private let paywall: @MainActor () -> (any CarouselPaywalling)?
    
    public init(
        wrapping wrapped: any ZTronPlaceableFactory,
        paywall: @escaping @MainActor () -> (any CarouselPaywalling)?
    ) {
        self.wrapped = wrapped
        self.paywall = paywall
    }
    
    public func make(placeable: PlaceableOutlineDescriptor) -> [any PlaceableView] {
        guard self.paywall()?.shouldGate(.outline) != true else { return [] }
        
        var views = self.wrapped.make(placeable: placeable)
        
        if self.paywall()?.shouldGate(.colorPicker) == true {
            views.removeAll { $0 is PlaceableColorPicker }
        }
        
        return views
    }
    
    public func make(placeable: PlaceableBoundingCircleDescriptor) -> [any PlaceableView] {
        guard self.paywall()?.shouldGate(.boundingCircle) != true else { return [] }
        
        return self.wrapped.make(placeable: placeable)
    }
}
