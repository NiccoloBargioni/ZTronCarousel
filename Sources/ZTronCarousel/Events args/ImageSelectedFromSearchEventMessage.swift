import ZTronObservation
import ZTronCarouselCore

public final class ImageSelectedFromSearchEventMessage: BroadcastArgs, @unchecked Sendable {
    private let galleryPath: [ZTronGalleryDescriptor]
    private let selectedImage: SearchableImage
    
    public init(source: any Component, galleryPath: [ZTronGalleryDescriptor], selectedImage: SearchableImage) {
        self.galleryPath = galleryPath
        self.selectedImage = selectedImage
        super.init(source: source)
    }
    
    public func getGalleryPath() -> [ZTronGalleryDescriptor] {
        return Array(self.galleryPath)
    }
    
    public func getSelectedImage() -> SearchableImage { // Immutable anyway
        return self.selectedImage
    }
}
