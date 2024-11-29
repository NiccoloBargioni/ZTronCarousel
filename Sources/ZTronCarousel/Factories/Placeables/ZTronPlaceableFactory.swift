import Foundation

@MainActor public protocol ZTronPlaceableFactory: Sendable {
    func make(placeable: PlaceableOutlineDescriptor) -> [any PlaceableView]
    func make(placeable: PlaceableBoundingCircleDescriptor) -> [any PlaceableView]
    func make(placeable: any PlaceableDescriptor) -> [any PlaceableView]
}

public extension ZTronPlaceableFactory {
    func make(placeable: any PlaceableDescriptor) -> [any PlaceableView] {
        
        // Swift doesn't perform dynamic dispatch of methods outside of class hierarchies :((
        switch placeable.descriptorType.rawValue {
        case PlaceableDescriptorType.outline:
            guard let outline = placeable as? PlaceableOutlineDescriptor else {
                fatalError()
            }
            
            return self.make(placeable: outline)
            
        case PlaceableDescriptorType.boundingCircle:
            guard let bc = placeable as? PlaceableBoundingCircleDescriptor else {
                fatalError()
            }
            
            return self.make(placeable: bc)
            
            default:
            fatalError("Update factory to accomodate for new placeable type \(placeable.descriptorType)")
        }
    }
}
