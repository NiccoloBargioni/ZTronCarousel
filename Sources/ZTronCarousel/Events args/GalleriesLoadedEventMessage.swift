import ZTronObservation
import SwiftGraph

public final class GalleriesLoadedEventMessage: BroadcastArgs, @unchecked Sendable {
    private(set) public var galleries: [ZTronGalleryDescriptor]
    
    public init(source: any Component, galleries: [ZTronGalleryDescriptor]) {
        self.galleries = galleries
        super.init(source: source)
    }
    
}
