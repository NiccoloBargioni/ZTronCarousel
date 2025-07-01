import ZTronObservation
import UIKit
import ZTronTheme

@MainActor public protocol AnyCaptionView: Component, AnyObject, UIView {
    func setText(body: String) -> Void
    var displayStrategy: CaptionDisplayStrategy { get }
    
    func setTheme(_ theme: any ZTronTheme)
}

public enum CaptionDisplayStrategy: Hashable, Sendable, Equatable {
    case below
    case overlay
}
