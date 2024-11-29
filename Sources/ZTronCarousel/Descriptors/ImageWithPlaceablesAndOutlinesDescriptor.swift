import Foundation
import ZTronCarouselCore

public class ImageWithPlaceablesAndOverlaysDescriptor: ZTronImageDescriptor {
    private let placeablesDescriptors: [any PlaceableDescriptor]
    private let overlaysDescriptors: [any OverlayDescriptor]

    public init(assetName: String, in bundle: Bundle? = .main, placeablesDescriptors: [any PlaceableDescriptor], overlaysDescriptors: [any OverlayDescriptor]) {
        self.placeablesDescriptors = placeablesDescriptors
        self.overlaysDescriptors = overlaysDescriptors
        super.init(assetName: assetName, in: bundle)
    }
    
    public func getPlaceableDescriptors() -> [any PlaceableDescriptor] {
        return Array(self.placeablesDescriptors)
    }
    
    public func getOverlaysDescriptors() -> [any OverlayDescriptor] {
        return Array(self.overlaysDescriptors)
    }
}
