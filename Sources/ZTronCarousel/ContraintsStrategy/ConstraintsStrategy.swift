import UIKit

@MainActor public protocol ConstraintsStrategy: AnyObject {
    var owner: CarouselPageFromDB? { get }
    
    func makePageWrapperConstraints(for orientation: UIDeviceOrientation) -> Void
    func makeScrollViewContentConstraints(for orientation: UIDeviceOrientation) -> Void
    
    func updatePageWrapperConstraintsForTransition(to orientation: UIDeviceOrientation, sizeAfterTransition: CGSize) -> Void
    func updateScrollViewContentConstraintsForTransition(to orientation: UIDeviceOrientation, sizeAfterTransition: CGSize) -> Void
}
