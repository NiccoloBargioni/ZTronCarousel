import UIKit

public final class EmptyOverlayFactory: ZTronOverlayFactory, Sendable {
    public func make(overlay: any OverlayDescriptor) -> [UIView] {
        return []
    }
}
