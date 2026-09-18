import UIKit
import SwiftSVG
import SnapKit

import ZTronObservation
import ZTronCarouselCore

public final class ZTronSVGView: UIView, PlaceableColoredView, @preconcurrency Component, Sendable {
    private(set) public var id: String = "outline"
    private(set) public var parentImage: String
    
    private var svgView: UIView!
    private let outlineAssetName: String
    private let normalizedAABB: CGRect
    private var svgLayer: SVGLayer!
    private var colorPicker: UIColorPickerViewController!
    
    private var overrideOffsetX: CGFloat? = nil
    private var overrideOffsetY: CGFloat? = nil
    private var overrideWidth: CGFloat? = nil
    private var overrideHeight: CGFloat? = nil
    
    private var lastContainerSize: CGSize? = nil
    private var needsInitialLayout: Bool = true
    
    /// Set while a CDN network fetch for this outline has failed and is waiting for connectivity
    /// to come back — see `resolveSVGViaCDN`/`registerConnectivityRetry`. `nil` whenever nothing
    /// is pending, including once the outline has resolved successfully.
    private var pendingConnectivityRetryToken: UUID? = nil
    
    private static let MIN_LINE_WIDTH: CGFloat = 5
    private var maxLineWidth: CGFloat {
        if sqrt(self.normalizedAABB.height * self.normalizedAABB.height + self.normalizedAABB.width * self.normalizedAABB.width) >= 0.07 {
            return 7.5
        } else {
            return 37.0
        }
    }
    
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
        self.id = "\(descriptor.getParentImage()) outline"
        self.outlineAssetName = descriptor.getOutlineAssetName()
        
        self.normalizedAABB = descriptor.getOutlineBoundingBox()
        
        self.lineWidth = .zero
        self.parentImage = descriptor.getParentImage()
        
        let svgURL = Self.resolveSVGURL(assetName: descriptor.getOutlineAssetName())
        
        super.init(frame: .zero)
        
        self.lineWidth = self.maxLineWidth
        
        var strokeColor = UIColor.colorWithHexString(descriptor.getColorHex())
        strokeColor = strokeColor.withAlphaComponent(descriptor.getOpacity())
        
        self.strokeColor = strokeColor.cgColor
        
        // Plain host view: unlike `SVGView(svgURL:)`, nothing gets attached to it
        // until the layer is fully configured (see `attach(_:)` below).
        self.svgView = UIView()
        
        if let svgURL {
            Self.parseAndAttach(svgURL, into: self)
        } else {
            // Neither the bundle nor the local CDN cache had it (see `resolveSVGURL`). In a
            // correctly functioning app this is a dead path — the bulk sync already placed it
            // locally before this view was ever constructed — so this exists purely as a
            // safeguard for when that first network call didn't happen or didn't finish: a
            // genuinely missing outline still just doesn't render, gracefully, no crash.
            self.resolveSVGViaCDN()
        }
        
        self.addSubview(svgView)
        
        
        if !descriptor.getIsActive() {
            self.alpha = 0
            self.isHidden = true
        }
        
        svgView.translatesAutoresizingMaskIntoConstraints = false
        svgView.layer.anchorPoint = CGPoint(x: 0, y: 0)
        
        if let parentView = svgView.superview {
            NSLayoutConstraint.activate([
                svgView.topAnchor.constraint(equalTo: parentView.safeAreaLayoutGuide.topAnchor),
                svgView.leftAnchor.constraint(equalTo: parentView.safeAreaLayoutGuide.leftAnchor),
            ])
        }
    }
    
    required init(coder: NSCoder) {
        fatalError("Cannot instantiate from Storyboard. Aborting")
    }
    
    /// First two steps of the fallback chain, both synchronous and both fully local: the app
    /// bundle (unchanged from before this feature existed — this used to be a `fatalError` when it
    /// missed), then the local CDN cache directory, itself just a filesystem check.
    private static func resolveSVGURL(assetName: String) -> URL? {
        if let bundleURL = Bundle.main.url(forResource: assetName, withExtension: "svg") {
            return bundleURL
        }
        
        return CDNLocalStore.shared.existingLocalURL(identifier: assetName, candidateExtensions: ["svg"])
    }
    
    /// Third and last step: an on-demand network fetch, reached only when the outline's SVG was in
    /// neither the bundle nor the local CDN cache. A no-op if no `CDNAssetResolver` was installed,
    /// so this costs nothing for an app that doesn't use the CDN feature.
    ///
    /// This intentionally lives here rather than in `BasicImagePage`, even though the earlier
    /// version of this fallback was framed as living alongside the image's own network call:
    /// `BasicImagePage` only ever receives a plain `ZTronImageDescriptor`, and has no access to
    /// `PlaceableOutlineDescriptor.getOutlineAssetName()` — which, reading its definition, is an
    /// independently-supplied identifier with no guaranteed relationship to the parent image's own
    /// `getAssetName()` (they're separate constructor parameters, not derived from one another).
    /// `BasicImagePage` genuinely cannot look up the right identifier for an outline it has no
    /// reference to; `ZTronSVGView` already has the correct one, since it's constructed directly
    /// from the `PlaceableOutlineDescriptor` that owns it.
    private func resolveSVGViaCDN() {
        guard let resolver = CDNAssetResolver.installed else { return }
        self.attemptNetworkResolve(resolver: resolver)
    }
    
    private func attemptNetworkResolve(resolver: CDNAssetResolver) {
        let assetName = self.outlineAssetName
        
        Task { [weak self] in
            guard let url = await resolver.resolveViaNetwork(identifier: assetName, candidateExtensions: ["svg"]) else {
                guard let self else { return }
                await MainActor.run {
                    self.registerConnectivityRetry(resolver: resolver)
                }
                return
            }
            
            guard let self else { return }
            
            await MainActor.run {
                Self.parseAndAttach(url, into: self)
            }
        }
    }
    
    /// Registers a retry for the next time `NetworkAvailabilityMonitor` reports connectivity
    /// available — "just in case" this particular failure was the device having no connectivity
    /// at that instant rather than the CDN genuinely lacking the asset. At most one retry is ever
    /// pending per instance; a retry that itself fails re-registers for the next connectivity
    /// event, so this keeps trying until it succeeds or the view is deallocated.
    private func registerConnectivityRetry(resolver: CDNAssetResolver) {
        guard self.pendingConnectivityRetryToken == nil else { return }
        
        self.pendingConnectivityRetryToken = NetworkAvailabilityMonitor.shared.retryWhenAvailable { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                
                self.pendingConnectivityRetryToken = nil
                
                // Only worth trying again if nothing else has already resolved this in the
                // meantime (a later sync, or a different retry path).
                guard self.svgLayer == nil else { return }
                
                self.attemptNetworkResolve(resolver: resolver)
            }
        }
    }
    
    /// `CALayer(svgURL:)` parses without attaching the result to any layer that is
    /// on screen: the throwaway receiver never enters the render tree, so nothing
    /// is displayed until `attach(_:)` adds the configured layer ourselves.
    private static func parseAndAttach(_ url: URL, into view: ZTronSVGView) {
        CALayer(svgURL: url) { [weak view] svgLayer in
            // SwiftSVG (master) invokes this on the main thread, in which case attaching
            // immediately keeps everything in the current CATransaction. The async branch
            // only exists as a safety net for SwiftSVG versions whose asynchronous path
            // parser completes on a background queue.
            if Thread.isMainThread {
                view?.attach(svgLayer)
            } else {
                DispatchQueue.main.async { [weak view] in
                    view?.attach(svgLayer)
                }
            }
        }
    }
    
    /// Styles and sizes the parsed layer, then adds it to the layer tree in the same
    /// `CATransaction`. Because the layer's first on-screen commit already carries its
    /// final `path`/`transform`/`fillColor`/`strokeColor`, Core Animation has no previous
    /// state to animate from: the outline appears directly in its final configuration.
    /// - Warning: Must be called on the main thread.
    private func attach(_ svgLayer: SVGLayer) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        self.svgLayer = svgLayer
        Self.disableImplicitAnimations(on: svgLayer)
        
        svgLayer.lineWidth = self.lineWidth
        svgLayer.strokeColor = self.strokeColor
        svgLayer.fillColor = nil
        svgLayer.resizeToFit(self.bounds)
        
        self.svgView.layer.addSublayer(svgLayer)
        
        CATransaction.commit()
        
        // If the page already laid out while the SVG was still parsing, bring the
        // layer up to date with the last known container size right away instead of
        // waiting for the next layout pass.
        if let containerSize = self.lastContainerSize {
            self.resize(for: containerSize)
        }
    }
    
    /// Installs a `nil` action for every property this view ever mutates on the SVG
    /// layer tree, on the container and recursively on every sublayer (SwiftSVG keeps
    /// one `CAShapeLayer` per path). Standalone `CALayer`s implicitly animate all such
    /// changes over 0.25s; this makes them apply instantly instead, for this initial
    /// attachment as well as every later `resize(for:)`, zoom and color update.
    /// Explicit `CAAnimation`s (and `UIView.animate` on the hosting views) still work.
    private static func disableImplicitAnimations(on layer: CALayer) {
        let disabled: [String: CAAction] = [
            "position": NSNull(),
            "bounds": NSNull(),
            "path": NSNull(),
            "transform": NSNull(),
            "sublayerTransform": NSNull(),
            "fillColor": NSNull(),
            "strokeColor": NSNull(),
            "lineWidth": NSNull(),
            "opacity": NSNull(),
            "hidden": NSNull(),
            "contents": NSNull(),
            "sublayers": NSNull(),
            "onOrderIn": NSNull(),
            "onOrderOut": NSNull()
        ]
        
        layer.actions = disabled
        layer.sublayers?.forEach { sublayer in
            Self.disableImplicitAnimations(on: sublayer)
        }
    }
    
    public final func resize(for containerSize: CGSize) {
        self.lastContainerSize = containerSize
        
        guard let svgView = self.svgView else { return }
        guard let svgLayer = self.svgLayer else { return }
        
        let newSize = self.getSize(for: containerSize)
        let newOrigin = self.getOrigin(for: containerSize)
        
        let newRect = CGRect(origin: newOrigin, size: newSize)
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        if self.hasAnyOverride() {
            let naturalSize = CGSize(
                width: containerSize.width * self.normalizedAABB.width,
                height: containerSize.height * self.normalizedAABB.height
            )
            
            svgLayer.resizeToFit(CGRect(origin: newOrigin, size: naturalSize))
            svgView.bounds = CGRect(origin: .zero, size: naturalSize)
            
            let scaleX = newSize.width / naturalSize.width
            let scaleY = newSize.height / naturalSize.height
            svgView.transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
        } else {
            svgLayer.resizeToFit(newRect)
            svgView.bounds = CGRect(origin: .zero, size: newSize)
            svgView.transform = .identity
        }
        
        CATransaction.commit()
        
        self.layoutIfNeeded()
    }
    
    public final func getOrigin(for containerSize: CGSize) -> CGPoint {
        return CGPoint(
            x: containerSize.width * (self.overrideOffsetX ?? self.normalizedAABB.origin.x),
            y: containerSize.height * (self.overrideOffsetY ?? self.normalizedAABB.origin.y)
        )
    }
    
    public final func getSize(for containerSize: CGSize) -> CGSize {
        return CGSize(
            width: containerSize.width * (self.overrideWidth ?? self.normalizedAABB.width),
            height: containerSize.height * (self.overrideHeight ?? self.normalizedAABB.height)
        )
    }
    
    public func updateForZoom(_ scrollView: UIScrollView) {
        self.lineWidth = max(
            Self.MIN_LINE_WIDTH,
            (Self.MIN_LINE_WIDTH...self.maxLineWidth).larp(
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
        
        if let token = self.pendingConnectivityRetryToken {
            NetworkAvailabilityMonitor.shared.cancelRetry(token)
        }
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
        if self.needsInitialLayout {
            self.needsInitialLayout = false
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.notifyPageToUpdateLayout()
            }
        }
    }
    
    public func viewWillDisappear() {
        self.delegate?.detach(or: .ignore)
    }
    
    public func dismantle() {
        self.setDelegate(nil)
    }
    
    internal func overrideOffsetX(_ x: CGFloat) -> Void {
        assert(x >= 0 && x <= 1)
        self.overrideOffsetX = x
        self.notifyPageToUpdateLayout()
    }
    
    internal func overrideOffsetY(_ y: CGFloat) -> Void {
        assert(y >= 0 && y <= 1)
        self.overrideOffsetY = y
        self.notifyPageToUpdateLayout()
    }
    
    internal func overrideSizeWidth(_ width: CGFloat) -> Void {
        assert(width >= 0 && width <= 1)
        self.overrideWidth = width
        self.notifyPageToUpdateLayout()
    }
    
    internal func overrideSizeHeight(_ height: CGFloat) -> Void {
        assert(height >= 0 && height <= 1)
        self.overrideHeight = height
        self.notifyPageToUpdateLayout()
    }
    
    private func notifyPageToUpdateLayout() {
        var currentView: UIView? = self.superview
        while let view = currentView {
            if let viewController = view.next as? ZTronImagePage {
                viewController.updatePlaceablesLayout()
                return
            }
            currentView = view.superview
        }
    }
    
    private func hasAnyOverride() -> Bool {
        return overrideOffsetX != nil || overrideOffsetY != nil ||
               overrideWidth != nil || overrideHeight != nil
    }
}
