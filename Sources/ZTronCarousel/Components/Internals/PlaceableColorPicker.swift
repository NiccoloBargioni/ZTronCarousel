import UIKit
import ZTronObservation
 
internal final class PlaceableColorPicker: UIView, PlaceableView, @preconcurrency Component, Sendable, UIPopoverPresentationControllerDelegate {
    private(set) internal var id: String = "color picker"
    private(set) internal var parentImage: String
    
    private var delegate: ColorPickerInteractionsManager?
    
    static private let MIN_OUTLINE_SIZE: CGFloat = 10
    static private let MAX_OUTLINE_SIZE: CGFloat = 50
    
    static private let MIN_SIZE_MULTIPLIER: CGFloat = 1.0
    static private let MAX_SIZE_MULTIPLIER: CGFloat = 3
    
    lazy private var colorPicker: UIColorPickerViewController = UIColorPickerViewController()
    private var selectedColor: UIColor = .clear
 
    private let hitboxCenter: CGPoint
    private var halfSideLength: CGFloat
    private var sizeMultiplier: CGFloat {
        didSet {
            self.setNeedsLayout()
        }
    }
    private var containerSizeEstimate: CGSize?
    private(set) internal var lastAction: PlaceableColorPicker.LastAction = .ready
    
    private var strokeColor: CGColor = .init(red: 1, green: 0, blue: 1, alpha: 1.ulp) {
        didSet {
            self.layer.borderColor = self.strokeColor
        }
    }
    
    internal init (descriptor: PlaceableOutlineDescriptor) {
        self.id = "\(descriptor.getParentImage()) color picker"
        let boundingBox = descriptor.getOutlineBoundingBox()
        
        self.halfSideLength = max(descriptor.getOutlineBoundingBox().size.width,
                                  descriptor.getOutlineBoundingBox().size.height)/2.0
        
        self.hitboxCenter = CGPoint(
            x: boundingBox.origin.x + boundingBox.size.width/2.0,
            y: boundingBox.origin.y + boundingBox.size.height/2.0
        )
        
 
        self.sizeMultiplier = Self.MAX_SIZE_MULTIPLIER
        self.containerSizeEstimate = nil
        self.parentImage = descriptor.getParentImage()
        super.init(frame: .zero)
 
        self.isUserInteractionEnabled = false // Otherwise clicks inside won't propagate
        
        self.layer.borderWidth = 1
        self.layer.borderColor = self.strokeColor
        
 
        self.addGestureRecognizer(
            UILongPressGestureRecognizer(target: self, action: #selector(self.presentColorPicker(_:)))
        )
        
        self.isUserInteractionEnabled = true
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("Cannot initialize from storyboards")
    }
    
    internal final func getOrigin(for containerSize: CGSize) -> CGPoint {
        self.containerSizeEstimate = containerSize
        
        let estimatedWidth = 2 * self.halfSideLength * sizeMultiplier * containerSize.width
        let estimatedHeight = 2 * self.halfSideLength * sizeMultiplier * containerSize.height
        
        let sideLength = max(estimatedWidth, estimatedHeight)
 
        
        return CGPoint(
            x: (self.hitboxCenter.x * containerSize.width - sideLength / 2.0),
            y: (self.hitboxCenter.y * containerSize.height  - sideLength / 2.0)
        )
    }
    
    internal final func getSize(for containerSize: CGSize) -> CGSize {
        self.containerSizeEstimate = containerSize
 
        let estimatedWidth = 2 * self.halfSideLength * containerSize.width * sizeMultiplier
        let estimatedHeight = 2 * self.halfSideLength * containerSize.height * sizeMultiplier
        
        let sideLength = max(estimatedWidth, estimatedHeight)
        
        return CGSize(
            width: sideLength,
            height: sideLength
        )
    }
    
    internal final func updateForZoom(_ scrollView: UIScrollView) {
        let zoomProgress = (scrollView.zoomScale - scrollView.minimumZoomScale)/(scrollView.maximumZoomScale - scrollView.minimumZoomScale)
        
        self.sizeMultiplier = max(
            Self.MIN_SIZE_MULTIPLIER,
            (Self.MIN_SIZE_MULTIPLIER...Self.MAX_SIZE_MULTIPLIER).larp((1-zoomProgress)*(1-zoomProgress)*(1-zoomProgress))
        )
    }
    
    internal final func resize(for containerSize: CGSize) {
        self.containerSizeEstimate = containerSize
 
        let frameForSize = CGRect(
            origin: self.getOrigin(for: containerSize),
            size: self.getSize(for: containerSize)
        )
        
        self.bounds = CGRect(
            origin: .zero,
            size: frameForSize.size
        )
    }
    
    internal final func colorChanged(_ color: UIColor) {
        self.strokeColor = color.cgColor
    }
    
    internal func getDelegate() -> (any ZTronObservation.InteractionsManager)? {
        return self.delegate
    }
    
    func setDelegate(_ interactionsManager: (any ZTronObservation.InteractionsManager)?) {
        guard let interactionsManager = interactionsManager as? ColorPickerInteractionsManager else {
            // Still it might be that interactionsmanager == nil
            if interactionsManager == nil {
                if let delegate = self.delegate {
                    delegate.detach()
                }
            } else {
                fatalError("Provide an interaction manager of type \(String(describing: ColorPickerInteractionsManager.self))")
            }
            
            self.delegate = nil
            
            return
        }
                
        if let delegate = self.delegate {
            delegate.detach()
        }
        
        self.delegate = interactionsManager
        
        interactionsManager.setup(or: .ignore)
    }
    
    public final func setStrokeColor(_ color: CGColor) {
        self.strokeColor = color
    }
    
    
    @objc private func presentColorPicker(_ sender: UITapGestureRecognizer) {
        
        switch sender.state {
        case .ended:
            if let parentViewController = self.parentViewController {
                self.isUserInteractionEnabled = false
                self.colorPicker.delegate = self
                self.colorPicker.modalPresentationStyle = .popover
                self.colorPicker.popoverPresentationController?.sourceView = self
                self.colorPicker.popoverPresentationController?.delegate = self
                if !self.colorPicker.isBeingPresented {
                    parentViewController.present(self.colorPicker, animated: true)
                }
            }
            
        default:
            break
        }
        
    }
    
    public func getSelectedColor() -> UIColor {
        return self.selectedColor
    }
    
    public func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return UIDevice.current.userInterfaceIdiom == .pad ? .popover : .none
    }
    
    public func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        self.isUserInteractionEnabled = true
    }
 
 
    deinit {
        self.delegate?.detach()
    }
    
    public func viewDidAppear() {
        self.delegate?.setup(or: .replace)
    }
    
    public func viewWillDisappear() {
        self.delegate?.detach(or: .ignore)
    }

    
    public func dismantle() {
        self.setDelegate(nil)
    }
    
    public enum LastAction {
        case ready
        case colorChangedContinuously
        case colorDidChange
    }
}
 
 
extension PlaceableColorPicker: UIColorPickerViewControllerDelegate {
    public func colorPickerViewController(_ viewController: UIColorPickerViewController, didSelect color: UIColor, continuously: Bool) {
        self.selectedColor = color
        
        if continuously {
            self.lastAction = .colorChangedContinuously
        } else {
            self.lastAction = .colorDidChange
        }
 
        self.delegate?.pushNotification(eventArgs: BroadcastArgs(source: self))
    }
}
 

