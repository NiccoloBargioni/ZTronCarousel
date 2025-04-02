import ZTronDataModel
import ZTronCarouselCore

public final class ZTronCarouselVideoDescriptor: ZTronVisualMediaDescriptor {
    private(set) public var type: ZTronCarouselCore.VisualMedia = .video

    private let assetName: String
    private let `extension`: String
    private let caption: String
    
    public init(
        assetName: String,
        extension: String,
        caption: String
    ) {
        self.assetName = assetName
        self.extension = `extension`
        self.caption = caption
    }
    
    public func getAssetName() -> String {
        return self.assetName
    }
    
    public func getExtension() -> String {
        return self.extension
    }
    
    public func getCaption() -> String {
        return self.caption
    }
}
