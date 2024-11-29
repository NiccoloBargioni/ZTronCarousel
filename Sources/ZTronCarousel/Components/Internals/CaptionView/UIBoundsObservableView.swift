import UIKit
@preconcurrency import Combine

open class UIBoundsObservableView: UILabel {
    public final let boundsPublisher: PassthroughSubject<CGRect, Never> = .init()
    
    override public var bounds: CGRect {
        didSet {
            self.boundsPublisher.send(bounds)
        }
    }
    
    deinit {
        self.boundsPublisher.send(completion: .finished)
    }
}
