import Foundation
import UIKit
import ZTronObservation
import ZTronSerializable

@MainActor public protocol ZTronComponentsFactory: AnyObject, Sendable {
    func makeViewModel() -> any AnyViewModel
    
    func makeDBLoader(with foreignKeys: SerializableGalleryForeignKeys) -> any AnyDBLoader
    func makeSearchController() -> (any AnySearchController)?
    
    /// - Pinned to left, top and right of this component
    /// - Height sized to fit its intrinsicContentSize
    /// - Disappears when `.orientation == .landscape`
    @available(
        *,
         deprecated,
         renamed: "makeTopbar(mediator:nestingLevel:maximumDepth:)",
         message: "Consider switching to topbar factory that takes nesting level into account"
    )
    func makeTopbar(mediator: MSAMediator) -> UIViewController?
    
    /// - Constraints will depend upon which topbar this is.
    /// - Disappears when `.orientation == .landscape`
    func makeTopbar(mediator: MSAMediator, nestingLevel: Int, maximumDepth: Int) -> UIViewController?
    
    
    /// - Pinned to left and right of carousel
    /// - Pinned to the bottom of carousel
    /// - Has `.defaultHigh` priority for `.vertical`
    /// - Disappears when `.orientation == .landscape`
    func makeBottomBar() -> any AnyBottomBar
    
    /// - Pinned to left and right of bottom bar
    /// - Pinned to the bottom of bottom bar
    /// - Has `.defaultHigh` priority for `.vertical`
    /// - Disappears when `.orientation == .landscape`
    func makeCaptionView() -> any AnyCaptionView
    
    
    /// Use this to customize the way views are arranged in the carousel
    /// - Parameter includesTopbar: Specifies whether or not the carousel should be built to include a topbar
    func makeConstraintsStrategy(owner: CarouselPageFromDB, _:Bool) -> any ConstraintsStrategy
    
    /// The paywall injected by default into every `CarouselPageFromDB` built through this factory.
    /// A paywall passed explicitly to `CarouselPageFromDB.init(paywall:)` — including the composite
    /// one accumulated by the SwiftUI `.paywalled` modifiers — takes precedence; when the explicit
    /// paywall is a `CompositeCarouselPaywall`, this one still acts as its fallback for the
    /// contents no explicit rule mentions.
    func makePaywall() -> (any CarouselPaywalling)?
}

public extension ZTronComponentsFactory {
    /// By default no paywall is injected: every content stays free.
    func makePaywall() -> (any CarouselPaywalling)? {
        return nil
    }
}
