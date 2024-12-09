import UIKit

public final class EmptyOverlayFactory: ZTronOverlayFactory, Sendable {
    public init() {  }

    public func make(overlay: any OverlayDescriptor) -> [UIView] {
        return []
    }
}
