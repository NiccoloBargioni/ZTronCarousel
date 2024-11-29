import Foundation
import ZTronObservation

public final class ZTronBasicPlaceableFactory<M>: ZTronPlaceableFactory, @unchecked Sendable
            where M: MSAMediator & AnyObject {
    
    weak private var mediator: M?
    
    init(mediator: M?) {
        self.mediator = mediator
    }
    
    public func make(placeable: PlaceableBoundingCircleDescriptor) -> [any PlaceableView] {
        guard let mediator = self.mediator else {
            return [CircleView(descriptor: placeable)]
        }
        
        let circleComponent = CircleView(descriptor: placeable)
        circleComponent.setDelegate(
            BoundingCircleInteractionsManager(owner: circleComponent, mediator: mediator)
        )
        
        return [circleComponent]
    }
    
    public func make(placeable: PlaceableOutlineDescriptor) -> [any PlaceableView] {
        guard let mediator = self.mediator else {
            return [ZTronSVGView(descriptor: placeable)]
        }
        
        let svgComponent = ZTronSVGView(descriptor: placeable)
        svgComponent.setDelegate(
            OutlineInteractionsManager(owner: svgComponent, mediator: mediator)
        )
        
        let placeableColorPicker = PlaceableColorPicker(descriptor: placeable)
        placeableColorPicker.setDelegate(ColorPickerInteractionsManager(owner: placeableColorPicker, mediator: mediator))

        
        return [svgComponent, placeableColorPicker]
    }
}
