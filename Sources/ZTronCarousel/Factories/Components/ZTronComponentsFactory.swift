import Foundation
import UIKit
import ZTronObservation
import ZTronSerializable

@MainActor public protocol ZTronComponentsFactory: AnyObject, Sendable {
    func makeViewModel() -> any AnyViewModel 
    
    func makeDBLoader(with foreignKeys: SerializableGalleryForeignKeys) -> any AnyDBLoader
    
    /// - Pinned to left, top and right of this component
    /// - Height sized to fit its intrinsicContentSize
    /// - Disappears when `.orientation == .landscape`
    func makeTopbar(mediator: MSAMediator) -> UIViewController
    
    /// - Pinned to left and right of carousel
    /// - Pinned to the bottom of carousel
    /// - Has `.defaultHigh` priority for `.vertical`
    /// - Disappears when `.orientation == .landscape`
    func makeBottomBar() -> any AnyBottomBar
    
    /// - Pinned to left and right of bottom bar
    /// - Pinned to the bottom of bottom bar
    /// - Has `.defaultHigh` priority for `.vertical`
    /// - Disappears when `.orientation == .landscape`
    func makeCaptionView() -> any AnyCaptionView
}
