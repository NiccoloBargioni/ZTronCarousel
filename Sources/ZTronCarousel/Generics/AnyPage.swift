import ZTronObservation
import ZTronCarouselCore

public protocol AnyPage: BasicImagePage, Component {
    @MainActor var imageName: String { get }
    @MainActor var lastAction: PageAction { get }
    
    @MainActor func attachAnimation(_ animationDescriptor: ImageVariantDescriptor, forward: Bool)
}

public enum PageAction: Sendable {
    case browsing
    case animationStarted
    case animationEnded
}

