import UIKit

/// Presents paywall prompts inside a medium-detent bottom sheet, on top of whatever is currently
/// frontmost.
@MainActor public enum PaywallSheetPresenter {
    public static func present(_ prompt: UIViewController, from sourceView: UIView, host: UIViewController?) {
        guard let presenter = host ?? sourceView.nearestViewController() else {
            #if DEBUG
            print("PaywallSheetPresenter: unable to locate a view controller to present the paywall prompt from. The gated action was suppressed but no sheet was shown.")
            #endif
            return
        }
        
        prompt.modalPresentationStyle = .pageSheet
        if let sheet = prompt.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 24
        }
        
        var topmost: UIViewController = presenter
        while let presented = topmost.presentedViewController {
            topmost = presented
        }
        
        topmost.present(prompt, animated: true)
    }
}

fileprivate extension UIView {
    /// Walks the responder chain toward the nearest view controller.
    func nearestViewController() -> UIViewController? {
        var responder: UIResponder? = self
        
        while let current = responder {
            if let viewController = current as? UIViewController {
                return viewController
            }
            
            responder = current.next
        }
        
        return nil
    }
}
