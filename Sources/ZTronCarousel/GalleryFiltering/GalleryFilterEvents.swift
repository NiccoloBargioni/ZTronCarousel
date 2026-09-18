import Foundation
import ZTronObservation

/// Type-erased facade over `GalleryFilteringCoordinator`, so that interactions managers can
/// discover it, signal interest and pattern-match on it without knowing its generic `Filter`
/// parameter (casting `Any` to an unbound generic type is not expressible in Swift).
public protocol AnyGalleryFilterCoordinator: Component, AnyObject {
    var lastAction: GalleryFilterCoordinatorAction { get }
}

public enum GalleryFilterCoordinatorAction: Sendable, Equatable {
    case ready
    /// The set of galleries whose medias are all excluded by the active filters changed.
    case gatingChanged
    /// The currently selected gallery has no matching media and the coordinator asked the topbar
    /// to switch to the nearest matching sibling.
    case redirectRequested
}

/// Broadcast whenever the set of galleries with zero medias satisfying the active filters changes
/// (including when it becomes empty because all filters were disabled).
///
/// Topbars react — when `depth` matches their own — by disabling the corresponding routing
/// elements and rendering them desaturated.
public final class GalleryFilterStateEventMessage: BroadcastArgs, @unchecked Sendable {
    /// The names of the galleries that currently have no media satisfying the active filters.
    private(set) public var disabledGalleries: Set<String>
    
    /// The topbar depth the evaluated sibling batch belongs to (compare against
    /// `AnyTopbarModel.getDepth()`).
    private(set) public var depth: Int
    
    public init(source: any Component, disabledGalleries: Set<String>, depth: Int) {
        self.disabledGalleries = disabledGalleries
        self.depth = depth
        super.init(source: source)
    }
}

/// Broadcast when the currently selected gallery has no matching media and
/// `EmptyGalleryFilteringPolicy.redirectToNearestSibling` is in force: asks the topbar at `depth`
/// to switch to `gallery` exactly as if the user had tapped its routing element.
public final class GalleryRedirectRequestEventMessage: BroadcastArgs, @unchecked Sendable {
    private(set) public var gallery: String
    private(set) public var depth: Int
    
    public init(source: any Component, gallery: String, depth: Int) {
        self.gallery = gallery
        self.depth = depth
        super.init(source: source)
    }
}
