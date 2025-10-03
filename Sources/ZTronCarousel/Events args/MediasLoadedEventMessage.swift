import ZTronObservation
import SwiftGraph

public final class MediasLoadedEventMessage: BroadcastArgs, @unchecked Sendable {
    private(set) public var medias: [any ZTronVisualMediaDescriptor]
    
    public init(source: any Component, medias: [any ZTronVisualMediaDescriptor]) {
        self.medias = medias
        super.init(source: source)
    }
}
