import ZTronObservation
import ZTronDataModel
import ZTronSerializable

public protocol AnyDBLoader: Component, AnyObject {
    var fk: SerializableGalleryForeignKeys { get }
    var lastAction: DBLoaderAction { get }
    
    func setCurrentDepth(_ depth: Int)
    func getCurrentDepth() -> Int
    
    func loadFirstLevelGalleries(_:String?) throws -> Void
    @discardableResult func loadImagesForGallery(_ theGallery: String?) throws -> String?
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
