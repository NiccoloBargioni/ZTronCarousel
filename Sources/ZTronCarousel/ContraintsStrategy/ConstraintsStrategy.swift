import UIKit

@MainActor internal protocol ConstraintsStrategy: AnyObject {
    var owner: CarouselPageWithTopbar? { get }
    
    func makeTopbarConstraints(for orientation: UIDeviceOrientation) -> Void
    func makePageWrapperConstraints(for orientation: UIDeviceOrientation) -> Void
    func makeScrollViewContentConstraints(for orientation: UIDeviceOrientation) -> Void
    
    func updatePageWrapperConstraintsForTransition(to orientation: UIDeviceOrientation, sizeAfterTransition: CGSize) -> Void
    func updateScrollViewContentConstraintsForTransition(to orientation: UIDeviceOrientation, sizeAfterTransition: CGSize) -> Void
}
