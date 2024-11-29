import Foundation
import ZTronObservation

public final class VariantLoadedEventMessage: BroadcastArgs, @unchecked Sendable {
    private let parentVariantDescriptor: ImageVariantDescriptor
    private let imageDescriptor: ZTronCarouselImageDescriptor
    
    public init(
        source: any Component,
        parentVariantDescriptor: ImageVariantDescriptor,
        imageDescriptor: ZTronCarouselImageDescriptor
    ) {
        self.parentVariantDescriptor = parentVariantDescriptor
        self.imageDescriptor = imageDescriptor
        super.init(source: source)
    }
    
    /// Returns an `ImageVariantDescriptor` where the `imageDescriptor` is the slave.
    public final func getParentVariantDescriptor() -> ImageVariantDescriptor {
        return self.parentVariantDescriptor
    }
    
    /// Returns the descriptor of the newly loaded image
    public final func getImageDescriptor() -> ZTronCarouselImageDescriptor {
        return self.imageDescriptor
    }
}
