import ZTronObservation
import ZTronDataModel

public protocol AnyDBLoader: Component, AnyObject {
    var lastAction: DBLoaderAction { get }
    
    func getGalleries() -> [SerializedGalleryModel]
    func getImages() -> [ZTronCarouselImageDescriptor]
    
    func loadFirstLevelGalleries() throws -> Void
    func loadImagesForGallery(_ theGallery: String) throws -> Void
    func loadGalleriesGraph() throws -> Void
    func loadImagesForSearch() throws -> Void
    
    func loadImageDescriptor(imageID: String, in gallery: String, variantDescriptor: ImageVariantDescriptor) throws
}

public enum DBLoaderAction: Sendable {
    case ready
    case galleriesLoaded
    case imagesLoaded
    case variantLoadedForward
    case variantLoadedBackward
    case loadedGalleriesGraph
    case imagesLoadedForSearch
}
