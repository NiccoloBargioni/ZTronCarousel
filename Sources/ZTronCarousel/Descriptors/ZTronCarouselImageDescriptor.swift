import Foundation
import ZTronCarouselCore

public protocol ZTronVisualMediaDescriptor: VisualMediaDescriptor {
    func getCaption() -> String
}

public final class ZTronCarouselImageDescriptor: ImageWithPlaceablesAndOverlaysDescriptor, ZTronVisualMediaDescriptor {
    private let caption: String
    private let variants: [ImageVariantDescriptor]?
    private let master: String?
    
    public init(
        assetName: String,
        in bundle: Bundle? = nil,
        caption: String,
        placeables: [any PlaceableDescriptor],
        overlays: [any OverlayDescriptor] = [],
        variants: [ImageVariantDescriptor]? = nil,
        master: String?
    ) {
        self.caption = caption
        self.variants = variants
        self.master = master
        super.init(
            assetName: assetName,
            in: bundle,
            placeablesDescriptors: placeables,
            overlaysDescriptors: overlays
        )
    }
        
    public func getMaster() -> String? {
        return self.master
    }
    
    public func getVariantsDescriptor() -> [ImageVariantDescriptor]? {
        guard let variants = self.variants else { return nil }
        return Array(variants)
    }
    
    public func getCaption() -> String {
        return self.caption
    }
    
    public func getMutableCopy() -> ZTronCarouselImageDescriptor.WritableDraft {
        return ZTronCarouselImageDescriptor.WritableDraft.from(self)
    }
    
    public final class WritableDraft {
        private let parent: ZTronCarouselImageDescriptor
        private var placeables: [any PlaceableDescriptor]
        
        private init(parent: ZTronCarouselImageDescriptor) {
            self.parent = parent
            self.placeables = parent.getPlaceableDescriptors()
        }
        
        public static func from(_ descriptor: ZTronCarouselImageDescriptor) -> ZTronCarouselImageDescriptor.WritableDraft {
            return self.init(parent: descriptor)
        }
        
        
        public func replacingOutline(_ produce: @escaping @Sendable (inout PlaceableOutlineDescriptor.WritableDraft) -> Void) -> ZTronCarouselImageDescriptor.WritableDraft {
            let outlineIndex = self.placeables.firstIndex { descriptor in
                return descriptor.descriptorType.rawValue == PlaceableDescriptorType.outline
            }
            
            if let outlineIndex = outlineIndex {
                if let outline = self.placeables[outlineIndex] as? PlaceableOutlineDescriptor {
                    var copy = outline.getMutableCopy()
                    produce(&copy)
                    self.placeables[outlineIndex] = copy.makeImmutableCopy()
                }
            }
            
            return self
        }
        
        
        public func replacingBoundingCircle(_ produce: @escaping @Sendable (inout PlaceableBoundingCircleDescriptor.WritableDraft) -> Void) -> ZTronCarouselImageDescriptor.WritableDraft {
            let boundingCircleIndex = self.placeables.firstIndex { descriptor in
                return descriptor.descriptorType.rawValue == PlaceableDescriptorType.boundingCircle
            }
            
            if let boundingCircleIndex = boundingCircleIndex {
                if let boundingCircle = self.placeables[boundingCircleIndex] as? PlaceableBoundingCircleDescriptor {
                    var copy = boundingCircle.getMutableCopy()
                    produce(&copy)
                    self.placeables[boundingCircleIndex] = copy.makeImmutableCopy()
                }
            }
            
            return self
        }
        
        public func getImmutableCopy() -> ZTronCarouselImageDescriptor {
            return ZTronCarouselImageDescriptor(
                assetName: parent.getAssetName(),
                caption: parent.getCaption(),
                placeables: placeables,
                overlays: parent.getOverlaysDescriptors(),
                variants: parent.getVariantsDescriptor(),
                master: parent.getMaster()
            )
        }
    }
}

public struct ZTronBoundingCircle: Sendable {
    internal let idleDiameter: Double?
    internal let normalizedCenter: CGPoint?

    init(idleDiameter: Double?, normalizedCenter: CGPoint?) {
        self.idleDiameter = idleDiameter
        self.normalizedCenter = normalizedCenter
    }
    
    internal func getIdleDiameter() -> Double? {
        return self.idleDiameter
    }
    
    internal func getNormalizedCenter() -> CGPoint? {
        return self.normalizedCenter
    }
}
