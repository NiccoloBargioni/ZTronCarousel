import ZTronObservation
import SwiftGraph

public final class GalleriesGraphLoadedEventMessage: BroadcastArgs, @unchecked Sendable {
    private(set) public var galleries: UnweightedGraph<ZTronGalleryDescriptor>
    
    public init(source: any Component, galleries: UnweightedGraph<ZTronGalleryDescriptor>) {
        self.galleries = galleries
        super.init(source: source)
    }
}
