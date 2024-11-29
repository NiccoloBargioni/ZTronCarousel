import ZTronCarouselCore
import ZTronObservation

public final class DefaultZTronMediaFactory: MediaFactory, Notifiable {
    nonisolated lazy private var mediator: MSAMediator? = nil
    
    public init(mediator: MSAMediator? = nil) {
        self.mediator = mediator
    }
    
    public func makeVideoPage(for videoDescriptor: ZTronVideoDescriptor) -> (any CountedUIViewController)? {
        return BasicVideoPage(videoDescriptor: videoDescriptor)
    }
    
    public func makeImagePage(for imageDescriptor: ZTronImageDescriptor) -> any CountedUIViewController {
        guard let outlinedDescriptor = imageDescriptor as? ZTronCarouselImageDescriptor else { fatalError("Expected image descriptor to be an outlined image descriptor.") }
        if let mediator = self.mediator {
            return ZTronImagePage(imageDescriptor: outlinedDescriptor, mediator: mediator)
        } else {
            return ZTronImagePage(imageDescriptor: outlinedDescriptor)
        }
    }
    
    nonisolated public func setMediator(_ mediator: MSAMediator?) {
        self.mediator = mediator
    }
}
