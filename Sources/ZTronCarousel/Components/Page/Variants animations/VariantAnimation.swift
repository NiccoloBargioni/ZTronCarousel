import UIKit

public protocol VariantAnimation: UIView, PlaceableView {
    func start() -> Void
    func viewWillTransitionTo(size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) -> Void
}

public extension VariantAnimation {
    func viewWillTransitionTo(size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) -> Void {}
}
