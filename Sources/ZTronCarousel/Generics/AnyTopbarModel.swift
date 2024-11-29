import ZTronObservation
import SwiftUI

public protocol TopbarComponent: AnyObject, Sendable, Equatable {
    func getIcon() -> String
    func getName() -> String
}


public protocol AnyTopbarModel: Component, AnyObject, ObservableObject {
    func setIsRedacted(to isRedacted: Bool) -> Void
    func replaceItems(with items: [any TopbarComponent])
    func getSelectedItemName() -> String
}
