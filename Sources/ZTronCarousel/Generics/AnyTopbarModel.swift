import ZTronObservation
import SwiftUI

public protocol TopbarComponent: AnyObject, Sendable, Equatable {
    func getIcon() -> String
    func getName() -> String
}


public protocol AnyTopbarModel: Component, AnyObject, ObservableObject {
    var title: String { get }
    var redacted: Bool { get }
    
    var lastAction: TopbarAction { get }
    
    // MARK: FOR OBSERVABILITY
    func setIsRedacted(to isRedacted: Bool) -> Void
    func replaceItems(with items: [any TopbarComponent])
    func getSelectedItemName() -> String
    func switchTo(itemNamed: String)
    
    // MARK: FOR VIEW MODEL
    func count() -> Int
    func setSelectedItem(item: Int) -> Void
    func getSelectedItem() -> Int
    func get(_ pos: Int) -> any TopbarComponent
}
