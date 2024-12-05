import UIKit

open class SomeViewController: UIViewController, CountedUIViewController {
    
    override public func loadView() {
        view = CustomView(frame: .init(x: 0, y: 0, width: 400, height: 700))
    
        
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }
    
    override open func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        self.view.layoutSubviews()
        if let view = self.view as? CustomView {
            view.shouldLayout = false
        }
        
    }
    
    public final func onRotationCompletion() {
        if let view = self.view as? CustomView {
            view.shouldLayout = true
        }

        self.view.setNeedsLayout()
    }

}
