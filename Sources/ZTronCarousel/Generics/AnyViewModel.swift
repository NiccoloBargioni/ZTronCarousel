import ZTronObservation
import Foundation

public protocol AnyViewModel: Component, Sendable, AnyObject {
    var viewModel: CarouselPageFromDB? { get set }
    var lastAction: CarouselFromDBLastAction { get }
    
    @MainActor func show() -> Void
    @MainActor func hide() -> Void
    @MainActor func switchPage(_ to: Int)
    @MainActor func loadImages() throws -> Void
    @MainActor func toggleCaption() -> Void
    
    
    func updateOutlineOriginX(_ x: CGFloat)
    func updateOutlineOriginY(_ x: CGFloat)
    func updateOutlineWidth(_ x: CGFloat)
    func updateOutlineHeight(_ x: CGFloat)
    
}
