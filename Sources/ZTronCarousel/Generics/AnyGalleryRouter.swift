import Foundation
import ZTronObservation

public protocol AnyGalleryRouter: Component {
    var currentImage: Int { get }
    var lastAction: GalleryRouterAction { get }
    
    func onImagesChanged(_ images: [any ZTronVisualMediaDescriptor]) -> Void
}

public enum GalleryRouterAction: Hashable, Sendable {
    case ready
    case next
    case previous
    case skip(Int)
}
