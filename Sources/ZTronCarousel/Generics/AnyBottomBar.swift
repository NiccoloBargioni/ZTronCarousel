import ZTronObservation
import UIKit


@MainActor public protocol AnyBottomBar: Component, AnyObject, UIView {
    @MainActor var lastAction: BottomBarLastAction { get }
    @MainActor var currentImage: String? { get }
    @MainActor var lastTappedVariantDescriptor: ImageVariantDescriptor? { get }

    
    @MainActor func switchVariants(_ to: [ImageVariantDescriptor], completion: ((_ completed: Bool) -> Void)?)
    @MainActor func appendGoBackVariant(icon: String?)
    @MainActor func clearVariantsStack(completion: ((Bool) -> Void)?)
    nonisolated func setCurrentImage(_ to: String)
}

public enum BottomBarLastAction: Equatable {
    case ready
    case toggleOutline
    case toggleBoundingCircle
    case tappedVariantChange
    case tappedGoBack
}
