import Foundation

public protocol AnyTopbarViewModel {
    func count() -> Int
    func getSelectedItem() -> Int
    func onItemsReplaced(_ action: @escaping ([any TopbarComponent]) -> Void) -> Void
    func setSelectedItem(item: Int) -> Void
    func get(_ pos: Int) -> any TopbarComponent
    
    func onHideRequest(_ action: @escaping () -> Void)
    func onShowRequest(_ action: @escaping () -> Void)
    
    // MARK: - TO SUPPORT FILTERING
    func isItemEnabled(_ name: String) -> Bool
    func onDisabledItemsChanged(_ action: @escaping (Set<String>) -> Void)
}

public extension AnyTopbarViewModel {
    /// View models that don't support filtering keep every item enabled.
    func isItemEnabled(_ name: String) -> Bool {
        return true
    }
    
    func onDisabledItemsChanged(_ action: @escaping (Set<String>) -> Void) {
        print("\(#function) NOT IMPLEMENTED")
    }
}
