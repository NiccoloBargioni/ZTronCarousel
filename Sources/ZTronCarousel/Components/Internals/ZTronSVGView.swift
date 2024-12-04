import UIKit
import SwiftSVG
import SnapKit

import ZTronObservation

public final class ZTronSVGView: UIView, PlaceableColoredView, @preconcurrency Component, Sendable {
    private(set) public var id: String = "outline"
    private(set) public var parentImage: String
    
    private var svgView: UIView!
    private let svgURL: URL
    private let normalizedAABB: CGRect
    private var svgLayer: SVGLayer!
    private var colorPicker: UIColorPickerViewController!
    
    private static let MIN_LINE_WIDTH: CGFloat = 5
    private static let MAX_LINE_WIDTH: CGFloat = 37
    
    private var delegate: OutlineInteractionsManager? = nil
    
    public var lineWidth: CGFloat {
        didSet {
            guard let svgLayer = self.svgLayer else { return }
            svgLayer.lineWidth = self.lineWidth
        }
    }
    
    private var strokeColor: CGColor = UIColor.clear.cgColor {
        didSet {
            guard let svgLayer = self.svgLayer else { return }
            svgLayer.strokeColor = self.strokeColor
        }
    }
    
    public init(descriptor: PlaceableOutlineDescriptor) {
        guard let url = Bundle.main.url(
            forResource: descriptor.getOutlineAssetName(),
            withExtension: "svg"
        ) else { fatalError("No resource named \(descriptor.getOutlineAssetName()).svg. Aborting.") }

        self.id = "\(descriptor.getParentImage()) outline"
        
        self.svgURL = url
        self.normalizedAABB = descriptor.getOutlineBoundingBox()
        
        self.lineWidth = Self.MAX_LINE_WIDTH
        
        self.parentImage = descriptor.getParentImage()
        
        super.init(frame: .zero)
        
        var strokeColor = UIColor.colorWithHexString(descriptor.getColorHex())
        strokeColor = strokeColor.withAlphaComponent(descriptor.getOpacity())
        
        self.strokeColor = strokeColor.cgColor
        
        self.svgView = SVGView(svgURL: url) { svgLayer in
            self.svgLayer = svgLayer
            svgLayer.lineWidth = self.lineWidth
            svgLayer.strokeColor = self.strokeColor
            svgLayer.fillColor = .none
            self.svgLayer.resizeToFit(self.bounds)
        }
        
        self.addSubview(svgView)
        
        
        if !descriptor.getIsActive() {
            self.alpha = 0
            self.isHidden = true
        }
        
        svgView.snp.makeConstraints { make in
            make.left.top.right.bottom.equalToSuperview()
        }
    }
    
    required init(coder: NSCoder) {
        fatalError("Cannot instantiate from Storyboard. Aborting")
    }
    
    public final func resize(for containerSize: CGSize) {
        guard let svgView = self.svgView else { return }
        guard let svgLayer = self.svgLayer else { return }
        let newRect = CGRect(
            x: self.getOrigin(for: containerSize).x,
            y: self.getOrigin(for: containerSize).y,
            width: self.getSize(for: containerSize).width,
            height: self.getSize(for: containerSize).height
        )
        
        svgLayer.resizeToFit(newRect)
        svgView.bounds = CGRect(origin: .zero, size: newRect.size)
        
        self.layoutIfNeeded()
    }
    
    public final func getOrigin(for containerSize: CGSize) -> CGPoint {
        return CGPoint(
            x: containerSize.width * self.normalizedAABB.origin.x,
            y: containerSize.height * self.normalizedAABB.origin.y
        )
    }
    
    public final func getSize(for containerSize: CGSize) -> CGSize {
        return CGSize(
            width: containerSize.width * self.normalizedAABB.width,
            height: containerSize.height * self.normalizedAABB.height
        )
    }
    
    public func updateForZoom(_ scrollView: UIScrollView) {
        self.lineWidth = max(
            Self.MIN_LINE_WIDTH,
            (Self.MIN_LINE_WIDTH...Self.MAX_LINE_WIDTH).larp(
                1 - (scrollView.zoomScale - scrollView.minimumZoomScale)/(scrollView.maximumZoomScale - scrollView.minimumZoomScale)
            )
        )
    }
        
    public func colorChanged(_ color: UIColor) {
        self.strokeColor = color.cgColor
    }
    
    public func getDelegate() -> (any ZTronObservation.InteractionsManager)? {
        return self.delegate
    }
    
    public func setDelegate(_ interactionsManager: (any ZTronObservation.InteractionsManager)?) {
        guard let interactionsManager = interactionsManager as? OutlineInteractionsManager else {
            // Still it might be that interactionsmanager == nil
            if interactionsManager == nil {
                if let delegate = self.delegate {
                    delegate.detach()
                }
            } else {
                fatalError("Provide an interaction manager of type \(String(describing: OutlineInteractionsManager.self))")
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
    
    deinit {
        self.delegate?.detach()
    }
    
    public final func setStrokeColor(_ color: CGColor) {
        self.strokeColor = color
    }
    
    public final func toggle() {
        UIView.animate(withDuration: 0.25) {
            if self.alpha <= 0 {
                self.isHidden.toggle()
            }
            
            self.alpha = self.alpha <= 0 ?  1 : 0
        } completion: { _ in
            if self.alpha <= 0 {
                self.isHidden.toggle()
            }
        }
    }
    
    
    public func viewDidAppear() {
        self.delegate?.setup(or: .replace)
    }
    
    public func viewWillDisappear() {
        self.delegate?.detach()
    }
    
    public func dismantle() {
        self.setDelegate(nil)
    }
}
