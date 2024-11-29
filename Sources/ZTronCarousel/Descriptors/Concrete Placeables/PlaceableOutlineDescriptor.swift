import Foundation

public final class PlaceableOutlineDescriptor: PlaceableDescriptor, Sendable {
    public let descriptorType: PlaceableDescriptorType
    
    private let outlineAssetName: String
    private let normalizedBoundingBox: CGRect
    private let parentImage: String
    private let colorHex: String
    private let opacity: Double
    private let isActive: Bool
    
    public init(
        parentImage: String,
        outlineAssetName: String,
        outlineBoundingBox: CGRect,
        colorHex: String,
        opacity: Double,
        isActive: Bool
    ) {
        assert(outlineBoundingBox.origin.x >= 0 && outlineBoundingBox.origin.x <= 1)
        assert(outlineBoundingBox.origin.y >= 0 && outlineBoundingBox.origin.y <= 1)
        assert(outlineBoundingBox.size.width >= 0 && outlineBoundingBox.size.width <= 1)
        assert(outlineBoundingBox.size.height >= 0 && outlineBoundingBox.size.height <= 1)
        assert(opacity >= 0 && opacity <= 1)
        assert(colorHex.isHexColor)
        
        self.outlineAssetName = outlineAssetName
        self.normalizedBoundingBox = outlineBoundingBox
        self.parentImage = parentImage
        self.colorHex = colorHex
        self.opacity = opacity
        self.isActive = isActive
        
        
        self.descriptorType = PlaceableDescriptorType(rawValue: PlaceableDescriptorType.outline)!
    }
    
    public func getParentImage() -> String {
        return self.parentImage
    }
    
    public func getOutlineAssetName() -> String {
        return self.outlineAssetName
    }
    
    public func getOutlineBoundingBox() -> CGRect {
        return CGRect(
            origin: self.normalizedBoundingBox.origin,
            size: self.normalizedBoundingBox.size
        )
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
    
    public func getMutableCopy() -> PlaceableOutlineDescriptor.WritableDraft {
        return PlaceableOutlineDescriptor.WritableDraft.from(self)
    }
    
    public final class WritableDraft {
        private let parent: PlaceableOutlineDescriptor
        
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
        
        private init(parent: PlaceableOutlineDescriptor) {
            self.colorHex = parent.getColorHex()
            self.opacity = parent.getOpacity()
            self.isActive = parent.getIsActive()
            self.parent = parent
        }
        
        
        public static func from(_ descriptor: PlaceableOutlineDescriptor) -> PlaceableOutlineDescriptor.WritableDraft {
            return self.init(parent: descriptor)
        }

        @discardableResult public func withColorHex(_ colorHex: String) -> PlaceableOutlineDescriptor.WritableDraft {
            assert(colorHex.isHexColor)
            self.colorHex = colorHex
            return self
        }
        
        @discardableResult public func withOpacity(_ opacity: Double) -> PlaceableOutlineDescriptor.WritableDraft {
            assert(opacity >= 0 && opacity <= 1)
            self.opacity = opacity
            return self
        }
        
        @discardableResult public func settingActive(_ isActive: Bool) -> PlaceableOutlineDescriptor.WritableDraft {
            self.isActive = isActive
            return self
        }
        
        @discardableResult public func togglingActive() -> PlaceableOutlineDescriptor.WritableDraft {
            self.isActive.toggle()
            return self
        }
        
        public func makeImmutableCopy() -> PlaceableOutlineDescriptor {
            if self.colorHexChanged || self.isActiveChanged || self.opacityChanged {
                return PlaceableOutlineDescriptor(
                    parentImage: self.parent.getParentImage(),
                    outlineAssetName: self.parent.getOutlineAssetName(),
                    outlineBoundingBox: self.parent.getOutlineBoundingBox(),
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
