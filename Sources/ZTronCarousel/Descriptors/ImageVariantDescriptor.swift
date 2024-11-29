import Foundation
import ZTronDataModel

public final class ImageVariantDescriptor: Sendable, Equatable {
    private let master: String
    private let slave: String
    private let variant: String
    private let bottomBarIcon: String
    private let goBackBottomBarIcon: String?
    private let boundingFrame: CGRect?
    
    public init(master: String, slave: String, variant: String, bottomBarIcon: String, goBackBottomBarIcon: String?, boundingFrame: CGRect?) {
        assert(boundingFrame == nil || (
            boundingFrame != nil &&
            boundingFrame!.origin.x >= 0 && boundingFrame!.origin.x <= 1 &&
            boundingFrame!.origin.y >= 0 && boundingFrame!.origin.y <= 1 &&
            boundingFrame!.size.width >= 0 && boundingFrame!.size.width <= 1 &&
            boundingFrame!.size.height >= 0 && boundingFrame!.size.height <= 1
        ))
        
        self.master = master
        self.slave = slave
        self.variant = variant
        self.bottomBarIcon = bottomBarIcon
        self.goBackBottomBarIcon = goBackBottomBarIcon
        self.boundingFrame = boundingFrame
    }
    
    convenience init(from: SerializedImageVariantMetadataModel) {
        self.init(
            master: from.getMaster(),
            slave: from.getSlave(),
            variant: from.getVariant(),
            bottomBarIcon: from.getBottomBarIcon(),
            goBackBottomBarIcon: from.getGoBackBottomBarIcon(),
            boundingFrame: from.getBoundingFrame()
        )
    }
    
    public func getMaster() -> String {
        return self.master
    }
    
    public func getSlave() -> String {
        return self.slave
    }
    
    public func getVariant() -> String {
        return self.variant
    }
    
    public func getGoBackBottomBarIcon() -> String? {
        return self.goBackBottomBarIcon
    }
    
    public func getBottomBarIcon() -> String {
        return self.bottomBarIcon
    }
    
    public func getBoundingFrame() -> CGRect {
        return self.boundingFrame ?? CGRect(
            x: 0, y: 0, width: 1.0, height: 1.0
        )
    }
    
    public static func == (lhs: ImageVariantDescriptor, rhs: ImageVariantDescriptor) -> Bool {
        return lhs.master == rhs.master && lhs.slave == rhs.slave && lhs.variant == rhs.variant && lhs.bottomBarIcon == rhs.bottomBarIcon &&
        (lhs.boundingFrame == nil && rhs.boundingFrame == nil) || (
            lhs.boundingFrame != nil && rhs.boundingFrame != nil &&
            lhs.boundingFrame!.equalTo(rhs.boundingFrame!)
        )
    }
}
