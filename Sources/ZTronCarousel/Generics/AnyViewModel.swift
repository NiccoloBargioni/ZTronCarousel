import ZTronObservation

public protocol AnyViewModel: Component, Sendable, AnyObject {
    var viewModel: CarouselPageFromDB? { get set }
    
    @MainActor func show() -> Void
    @MainActor func hide() -> Void
    @MainActor func switchPage(_ to: Int)
    @MainActor func loadImages() throws -> Void
}
