import UIKit
import ZTronObservation

/// Presents `UIColorPickerViewController` for the current image's outline, triggered from the
/// bottom bar's `.colorPicker` action, anchored to — and continuously tracking — the outline's
/// `ZTronSVGView`.
///
/// This is deliberately a separate mechanism from the long-press-triggered picker already
/// available directly on the outline (`PlaceableColorPicker`): that one is itself a placeable,
/// living inside the zoomed `imageView` and anchored via `sourceView = self`, which is the right
/// behavior for a marker that's part of the image content. This controller's popover must do the
/// opposite — stay outside the zoomed content and track the outline's on-screen position without
/// being affected by zoom itself — which calls for a different anchoring strategy entirely (see
/// `currentAnchorRect()`). Both ultimately call `ZTronSVGView.setStrokeColor(_:)`, so a color
/// picked from either stays consistent with the other; there's no shared state to reconcile.
///
/// One instance is created per page that has an outline (`ZTronImagePage.init`, alongside the
/// outline's own `ZTronSVGView`), registers in the same mediator, and — via
/// `ColorPickerPopoverInteractionsManager` — discovers the bottom bar and reacts only when
/// `bottomBar.currentImage` matches its own `parentImage`, exactly like `OutlineInteractionsManager`
/// does for the outline's own toggle.
@MainActor internal final class ColorPickerPopoverController: NSObject, Component {
    internal let id: String
    internal let parentImage: String
    
    private weak var svgView: ZTronSVGView?
    private weak var scrollView: UIScrollView?
    private weak var presentingViewController: UIViewController?
    
    nonisolated(unsafe) private var delegate: ColorPickerPopoverInteractionsManager? = nil
    
    private lazy var colorPickerViewController: UIColorPickerViewController = .init()
    nonisolated(unsafe) private var displayLink: CADisplayLink? = nil
    
    private(set) internal var isPresented: Bool = false
    
    internal init(svgView: ZTronSVGView, scrollView: UIScrollView, presentingViewController: UIViewController) {
        self.parentImage = svgView.parentImage
        self.id = "\(svgView.parentImage) bottom bar color picker"
        self.svgView = svgView
        self.scrollView = scrollView
        self.presentingViewController = presentingViewController
        super.init()
    }
    
    /// Presents the popover if it isn't showing, dismisses it if it is. Called by
    /// `ColorPickerPopoverInteractionsManager` when the bottom bar broadcasts `.tappedColorPicker`
    /// for this instance's `parentImage`.
    internal func togglePopover() {
        if self.isPresented {
            self.dismissPopover(animated: true)
        } else {
            self.presentPopover()
        }
    }
    
    private func presentPopover() {
        guard let presentingViewController = self.presentingViewController else { return }
        guard let scrollView = self.scrollView, scrollView.bounds.width > 0, scrollView.bounds.height > 0 else { return }
        guard !self.colorPickerViewController.isBeingPresented else { return }
        
        self.colorPickerViewController.delegate = self
        self.colorPickerViewController.modalPresentationStyle = .popover
        self.colorPickerViewController.popoverPresentationController?.delegate = self
        self.colorPickerViewController.popoverPresentationController?.sourceView = scrollView
        self.colorPickerViewController.popoverPresentationController?.sourceRect = self.currentAnchorRect()
        
        presentingViewController.present(self.colorPickerViewController, animated: true)
        
        self.isPresented = true
        self.startTracking()
        self.delegate?.syncBottomBar(isPresented: true)
    }
    
    /// Idempotent: safe to call whether the popover is currently showing or not, and safe to call
    /// twice for the same dismissal (once programmatically, once if `colorPickerViewControllerDidFinish`
    /// also fires for it) — the guard makes the second call a no-op.
    private func dismissPopover(animated: Bool) {
        guard self.isPresented else { return }
        
        self.stopTracking()
        self.isPresented = false
        
        if self.presentingViewController?.presentedViewController === self.colorPickerViewController {
            self.colorPickerViewController.dismiss(animated: animated)
        }
        
        self.delegate?.syncBottomBar(isPresented: false)
    }
    
    // MARK: - Tracking
    
    /// A `CADisplayLink`, rather than hooking `UIScrollViewDelegate`, so this stays entirely
    /// self-contained: no changes needed to `ZTronImagePage`'s scroll delegate, and — being
    /// per-frame rather than callback-driven — it uniformly covers every source of position change
    /// (drag, deceleration, zoom, bounce, rotation) without enumerating them. It only runs while a
    /// popover is actually presented, added in `.common` run-loop mode so it keeps firing while the
    /// user is actively dragging the scroll view, not just between gestures.
    private func startTracking() {
        self.displayLink?.invalidate()
        
        let link = CADisplayLink(target: self, selector: #selector(self.updateAnchor))
        link.add(to: .main, forMode: .common)
        self.displayLink = link
    }
    
    private func stopTracking() {
        self.displayLink?.invalidate()
        self.displayLink = nil
    }
    
    @objc private func updateAnchor() {
        guard self.isPresented else { return }
        self.colorPickerViewController.popoverPresentationController?.sourceRect = self.currentAnchorRect()
    }
    
    /// The rect `sourceRect` is set to, expressed in `scrollView`'s own frame — its non-zooming,
    /// non-scrolling coordinate space. The popover's content is a genuinely separate presentation
    /// (not a subview of `imageView`), so it never zooms by construction; this is the only place
    /// zoom and pan need to be accounted for at all, and only to compute where to point.
    ///
    /// While the outline is at least partially on screen, the anchor is its visible intersection
    /// with `scrollView.bounds`, so the popover slides continuously with whatever portion of the
    /// outline remains visible. Once it's scrolled fully out of view, the anchor collapses to a
    /// single point: the raw (off-screen) center, clamped into `scrollView.bounds` — this keeps the
    /// arrow pointing in the outline's true direction, and being continuous with the intersection
    /// case, produces no jump the moment the outline re-enters view.
    private func currentAnchorRect() -> CGRect {
        guard let scrollView = self.scrollView, let svgView = self.svgView else {
            return CGRect(x: 0, y: 0, width: 1, height: 1)
        }
        
        let bounds = scrollView.bounds
        let rawFrame = svgView.convert(svgView.bounds, to: scrollView)
        let intersection = rawFrame.intersection(bounds)
        
        if !intersection.isNull && !intersection.isEmpty {
            return intersection
        }
        
        let rawCenter = CGPoint(x: rawFrame.midX, y: rawFrame.midY)
        let clampedCenter = CGPoint(
            x: min(max(rawCenter.x, bounds.minX), bounds.maxX),
            y: min(max(rawCenter.y, bounds.minY), bounds.maxY)
        )
        
        return CGRect(x: clampedCenter.x, y: clampedCenter.y, width: 1, height: 1)
    }
    
    // MARK: - Lifecycle
    // Not a `PlaceableView` (it must not zoom, so it can't live in `self.placeables`), so
    // `ZTronImagePage` calls these explicitly alongside its own `viewDidAppear`/`viewWillDisappear`,
    // mirroring what `ZTronSVGView.viewDidAppear()`/`viewWillDisappear()` already do for themselves.
    
    internal func viewDidAppear() {
        self.delegate?.setup(or: .replace)
    }
    
    internal func viewWillDisappear() {
        // A popover presented from a page that's about to leave the screen (swiped away while
        // open) would be left anchored to nothing: dismiss it before detaching.
        self.dismissPopover(animated: false)
        self.delegate?.detach(or: .ignore)
    }
    
    // MARK: - Component
    
    nonisolated internal func getDelegate() -> (any InteractionsManager)? {
        return self.delegate
    }
    
    nonisolated internal func setDelegate(_ interactionsManager: (any InteractionsManager)?) {
        guard let interactionsManager = interactionsManager as? ColorPickerPopoverInteractionsManager else {
            if interactionsManager == nil {
                self.delegate?.detach(or: .ignore)
                self.delegate = nil
            } else {
                fatalError("Expected interactions manager of type \(String(describing: ColorPickerPopoverInteractionsManager.self)) in \(#function) at \(#file)")
            }
            
            return
        }
        
        self.delegate?.detach(or: .ignore)
        self.delegate = interactionsManager
        interactionsManager.setup(or: .ignore)
    }
    
    nonisolated internal static func == (lhs: ColorPickerPopoverController, rhs: ColorPickerPopoverController) -> Bool {
        return lhs.id == rhs.id
    }
    
    nonisolated internal override var hash: Int {
        return self.id.hashValue
    }
    
    deinit {
        self.displayLink?.invalidate()
        self.delegate?.detach(or: .ignore)
    }
}

// MARK: - UIColorPickerViewControllerDelegate

extension ColorPickerPopoverController: UIColorPickerViewControllerDelegate {
    internal func colorPickerViewController(_ viewController: UIColorPickerViewController, didSelect color: UIColor, continuously: Bool) {
        self.svgView?.setStrokeColor(color.cgColor)
    }
    
    internal func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
        // Covers dismissal the user initiated directly (swipe down / tap outside / Done), which
        // never goes through `togglePopover()`. Harmless no-op if we already dismissed it ourselves.
        self.dismissPopover(animated: false)
    }
}

// MARK: - UIPopoverPresentationControllerDelegate

extension ColorPickerPopoverController: UIPopoverPresentationControllerDelegate {
    /// Mirrors `PlaceableColorPicker`'s own implementation verbatim: `.none` here means "no
    /// adaptation," i.e. keep the `.popover` style on both idioms, not "no presentation."
    internal func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return UIDevice.current.userInterfaceIdiom == .pad ? .popover : .none
    }
}

// MARK: - Interactions manager

internal final class ColorPickerPopoverInteractionsManager: MSAInteractionsManager, @unchecked Sendable {
    weak private var owner: ColorPickerPopoverController?
    weak private var mediator: MSAMediator?
    
    /// The bottom bar, once discovered — kept so `syncBottomBar(isPresented:)` can reach it
    /// directly even when triggered by something other than an incoming bottom-bar notification
    /// (an external dismiss via `UIColorPickerViewControllerDelegate`, which is a system callback,
    /// not a mediator event).
    weak private var lastKnownBottomBar: (any AnyBottomBar)?
    
    internal init(owner: ColorPickerPopoverController, mediator: MSAMediator) {
        self.owner = owner
        self.mediator = mediator
    }
    
    internal func peerDiscovered(eventArgs: BroadcastArgs) {
        guard let owner = self.owner else { return }
        
        if let bottomBar = eventArgs.getSource() as? (any AnyBottomBar) {
            self.mediator?.signalInterest(owner, to: bottomBar, or: .ignore)
        }
    }
    
    internal func peerDidAttach(eventArgs: BroadcastArgs) {
        
    }
    
    internal func notify(args: BroadcastArgs) {
        guard let owner = self.owner else { return }
        
        if let bottomBar = args.getSource() as? (any AnyBottomBar) {
            self.lastKnownBottomBar = bottomBar

            Task(priority: .userInitiated) { @MainActor in
                if bottomBar.currentImage == owner.parentImage && bottomBar.lastAction == .tappedColorPicker {
                    owner.togglePopover()
                }
            }
        }
    }
    
    internal func willCheckout(args: BroadcastArgs) {
        
    }
    
    internal func getOwner() -> (any Component)? {
        return self.owner
    }
    
    internal func getMediator() -> (any Mediator)? {
        return self.mediator
    }
    
    /// Called by the owner whenever its presented state changes — from a tap-driven toggle or an
    /// external dismiss alike — so the bar's `.colorPicker` highlight stays correct regardless of
    /// which path caused the change. A no-op until the bottom bar has actually been discovered, or
    /// once this page's image is no longer the one displayed.
    internal func syncBottomBar(isPresented: Bool) {
        guard let owner = self.owner else { return }
        guard let bottomBar = self.lastKnownBottomBar else { return }

        Task(priority: .userInitiated) { @MainActor in
            guard bottomBar.currentImage == owner.parentImage else { return }
            bottomBar.setActive(isPresented, for: .colorPicker)
        }
    }
}
