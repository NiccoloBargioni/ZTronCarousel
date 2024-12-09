import Foundation
import SwiftGraph
import ZTronDataModel
import ZTronObservation


public protocol AnySearchController: AnyObject, Component {
    var lastAction: SearchControllerAction { get }
    func prepare() -> Void
    func galleriesLoaded(_ galleries: UnweightedGraph<ZTronGalleryDescriptor>) -> Void
    func imagesLoaded(_ images: [SearchableImage]) -> Void
    func selectedImage(_ image: SearchableImage) -> Void
    func searchCancelled() -> Void
}

public enum SearchControllerAction: Sendable {
    case ready
    case loadGalleriesGraph
    case loadAllMasterImages
    case imageSelected
    case cancelled
}
