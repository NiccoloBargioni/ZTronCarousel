import UIKit

public protocol ZTronOverlayFactory: Sendable, AnyObject {
    func make(overlay: any OverlayDescriptor) -> [UIView]
}
