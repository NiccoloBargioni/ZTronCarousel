import ZTronObservation
import SwiftGraph

public final class MediasLoadedEventMessage: BroadcastArgs, @unchecked Sendable {
    private(set) public var medias: [any ZTronVisualMediaDescriptor]
    public let depth: Int
    
    public init(
        source: any Component,
        medias: [any ZTronVisualMediaDescriptor],
        depth: Int
    ) {
        self.medias = medias
        self.depth = depth
        super.init(source: source)
    }
}
