import UIKit
import SwiftUI

public final class UICarouselComponentHostingController<Content: View>: UIHostingController<Content> {
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        if #available(iOS 16.0, *) {
            self.sizingOptions = .intrinsicContentSize
        }
    }
    
    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.view.invalidateIntrinsicContentSize()
    }
}
