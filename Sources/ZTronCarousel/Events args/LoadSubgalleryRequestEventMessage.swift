import ZTronObservation
import ZTronDataModel

public final class LoadSubgalleryRequestEventMessage: BroadcastArgs, @unchecked Sendable {
    public let master: String
    
    public init(source: any Component, master: String) {
        self.master = master
        super.init(source: source)
    }
}
