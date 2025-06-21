import ZTronObservation
import UIKit

@MainActor public protocol AnyCaptionView: Component, AnyObject, UIView {
    func setText(body: String) -> Void
    var displayStrategy: CaptionDisplayStrategy { get }
    
}

public enum CaptionDisplayStrategy: Hashable, Sendable, Equatable {
    case below
    case overlay
}
