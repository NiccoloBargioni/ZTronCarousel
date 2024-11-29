import ZTronObservation
import UIKit

@MainActor public protocol AnyCaptionView: Component, AnyObject, UIView {
    func setText(body: String) -> Void
}
