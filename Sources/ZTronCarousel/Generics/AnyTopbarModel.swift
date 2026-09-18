import ZTronObservation
import SwiftUI

public protocol TopbarComponent: AnyObject, Sendable, Equatable {
    var strategy: TopbarItemStrategy { get }
    func getIcon() -> String
    func getName() -> String
}


public protocol AnyTopbarModel: Component, AnyObject, ObservableObject {
    var title: String { get }
    var redacted: Bool { get }
    var selectedItemStrategy: TopbarItemStrategy { get }
    
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
    func getDepth() -> Int
    
    // MARK: - TO SUPPORT UIKIT TOPBARS
    func onRedactedChange(_ action: @escaping (Bool) -> Void) -> Void
    func onSelectedItemChanged(_ action: @escaping (Int) -> Void) -> Void
    func onItemsReplaced(_ action: @escaping ([any TopbarComponent]) -> Void) -> Void
    
    func hide() -> Void
    func show() -> Void
    
    func onHideRequest(_ action: @escaping () -> Void)
    func onShowRequest(_ action: @escaping () -> Void)
    
    // MARK: - TO SUPPORT FILTERING
    func setDisabledItems(_ names: Set<String>)
    func isItemEnabled(_ name: String) -> Bool
    func onDisabledItemsChanged(_ action: @escaping (Set<String>) -> Void)
}

public extension AnyTopbarModel {
    func onRedactedChange(_ action: @escaping (Bool) -> Void) -> Void {
        print("\(#function) NOT IMPLEMENTED")
    }
    
    func onSelectedItemChanged(_ action: @escaping (Int) -> Void) -> Void {
        print("\(#function) NOT IMPLEMENTED")
    }
    
    func onItemsReplaced(_ action: @escaping ([any TopbarComponent]) -> Void) -> Void {
        print("\(#function) NOT IMPLEMENTED")
    }
    
    /// Models that don't support filtering can ignore disabled items: with the defaults below every
    /// item stays enabled and selection is never gated.
    func setDisabledItems(_ names: Set<String>) {
        print("\(#function) NOT IMPLEMENTED")
    }
    
    func isItemEnabled(_ name: String) -> Bool {
        return true
    }
    
    func onDisabledItemsChanged(_ action: @escaping (Set<String>) -> Void) {
        print("\(#function) NOT IMPLEMENTED")
    }
}
