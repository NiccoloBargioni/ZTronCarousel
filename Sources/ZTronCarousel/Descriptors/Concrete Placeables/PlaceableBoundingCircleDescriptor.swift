import Foundation

public final class PlaceableBoundingCircleDescriptor: PlaceableDescriptor, Sendable {
    public let descriptorType: PlaceableDescriptorType
        
    private let boundingCircle: ZTronBoundingCircle
    private let boundingBox: CGRect?
    private let parentImage: String
    private let colorHex: String
    private let opacity: Double
    private let isActive: Bool
    
    init(
        parentImageID: String,
        boundingCircle: ZTronBoundingCircle,
        normalizedBoundingBox: CGRect?,
        colorHex: String,
        opacity: Double,
        isActive: Bool
    ) {
        assert(boundingCircle.getIdleDiameter() != nil || boundingCircle.getIdleDiameter() == nil && normalizedBoundingBox != nil)
        assert(colorHex.isHexColor)
        assert(opacity >= 0 && opacity <= 1)
        
        if let normalizedBoundingBox = normalizedBoundingBox {
            assert(normalizedBoundingBox.origin.x >= 0 && normalizedBoundingBox.origin.x <= 1)
            assert(normalizedBoundingBox.origin.y >= 0 && normalizedBoundingBox.origin.y <= 1)
            assert(normalizedBoundingBox.size.width >= 0 && normalizedBoundingBox.size.width <= 1)
            assert(normalizedBoundingBox.size.height >= 0 && normalizedBoundingBox.size.height <= 1)
        }

        self.boundingCircle = boundingCircle
        self.boundingBox = normalizedBoundingBox
        self.parentImage = parentImageID
        self.colorHex = colorHex
        self.opacity = opacity
        self.isActive = isActive
        
        self.descriptorType = PlaceableDescriptorType(rawValue: PlaceableDescriptorType.boundingCircle)!
    }
    
    public func getOutlineBoundingCircle() -> ZTronBoundingCircle  {
        return self.boundingCircle
    }
    
    public func getNormalizedBoundingBox() -> CGRect? {
        guard let boundingBox = self.boundingBox else { return nil }
        return CGRect(origin: boundingBox.origin, size: boundingBox.size)
    }
    
    public func getColorHex() -> String {
        return self.colorHex
    }
    
    public func getOpacity() -> Double {
        return self.opacity
    }
    
    public func getIsActive() -> Bool {
        return self.isActive
    }
    
    public func getParentImage() -> String {
        return self.parentImage
    }
    
    public func getMutableCopy() -> PlaceableBoundingCircleDescriptor.WritableDraft {
        return PlaceableBoundingCircleDescriptor.WritableDraft.from(self)
    }
    
    public final class WritableDraft {
        private let parent: PlaceableBoundingCircleDescriptor
        
        private var colorHex: String {
            didSet {
                self.colorHexChanged = true
            }
        }
        
        private var opacity: Double {
            didSet {
                self.opacityChanged = true
            }
        }
        
        private var isActive: Bool {
            didSet {
                self.isActiveChanged = true
            }
        }
        
        private var colorHexChanged: Bool = false
        private var opacityChanged: Bool = false
        private var isActiveChanged: Bool = false
        
        private init(parent: PlaceableBoundingCircleDescriptor) {
            self.colorHex = parent.getColorHex()
            self.opacity = parent.getOpacity()
            self.isActive = parent.getIsActive()
            self.parent = parent
        }
        
        
        public static func from(_ descriptor: PlaceableBoundingCircleDescriptor) -> PlaceableBoundingCircleDescriptor.WritableDraft {
            return self.init(parent: descriptor)
        }

        @discardableResult public func withColorHex(_ colorHex: String) -> PlaceableBoundingCircleDescriptor.WritableDraft {
            assert(colorHex.isHexColor)
            self.colorHex = colorHex
            return self
        }
        
        @discardableResult public func withOpacity(_ opacity: Double) -> PlaceableBoundingCircleDescriptor.WritableDraft {
            assert(opacity >= 0 && opacity <= 1)
            self.opacity = opacity
            return self
        }
        
        @discardableResult public func settingActive(_ isActive: Bool) -> PlaceableBoundingCircleDescriptor.WritableDraft {
            self.isActive = isActive
            return self
        }
        
        @discardableResult public func togglingActive() -> PlaceableBoundingCircleDescriptor.WritableDraft {
            self.isActive.toggle()
            return self
        }
        
        public func makeImmutableCopy() -> PlaceableBoundingCircleDescriptor {
            if self.colorHexChanged || self.isActiveChanged || self.opacityChanged {
                return PlaceableBoundingCircleDescriptor(
                    parentImageID: self.parent.getParentImage(),
                    boundingCircle: self.parent.getOutlineBoundingCircle(),
                    normalizedBoundingBox: self.parent.getNormalizedBoundingBox(),
                    colorHex: self.colorHex,
                    opacity: self.opacity,
                    isActive: self.isActive
                )
            } else {
                return self.parent
            }
        }
    }
}
