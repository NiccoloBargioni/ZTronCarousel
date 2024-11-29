import UIKit

open class BottomSeparatedUIView: UIView {
    private var borderLayer: CALayer? = nil

    
    override public var bounds: CGRect {
        didSet {
            self.borderLayer?.removeFromSuperlayer()
            self.borderLayer = CALayer()
            
            
            borderLayer!.borderColor = UIColor.separator.cgColor
            borderLayer!.borderWidth = 0.3
            borderLayer!.frame = CGRect(x: 0, y: self.frame.size.height-0.3, width: self.frame.size.width, height: 0.3)
            
            
            self.layer.addSublayer(borderLayer!)
        }
    }

}
