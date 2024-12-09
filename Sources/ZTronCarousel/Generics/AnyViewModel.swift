import ZTronObservation

public protocol AnyViewModel: Component, Sendable, AnyObject {
    var viewModel: CarouselPageWithTopbar? { get set }
    
    @MainActor func show() -> Void
    @MainActor func hide() -> Void
}
