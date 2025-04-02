import ZTronDataModel
import ZTronCarouselCore

public final class ZTronCarouselVideoDescriptor: ZTronVideoDescriptor, ZTronVisualMediaDescriptor {
    private let caption: String
    
    public init(
        assetName: String,
        extension: String,
        caption: String
    ) {
        self.caption = caption
        super.init(assetName: assetName, withExtension: `extension`)
    }
        
    public func getCaption() -> String {
        return self.caption
    }
}
