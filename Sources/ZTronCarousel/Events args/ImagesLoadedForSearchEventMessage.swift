import ZTronObservation
import ZTronDataModel

public final class ImagesLoadedForSearchEventMessage: BroadcastArgs, @unchecked Sendable {
    public let images: [SerializedImageModel]
    
    public init(source: any Component, images: [SerializedImageModel]) {
        self.images = images
        super.init(source: source)
    }
}
