import Foundation

public protocol AnyTopbarViewModel {
    func count() -> Int
    func getSelectedItem() -> Int
    func onItemsReplaced(_ action: @escaping ([any TopbarComponent]) -> Void) -> Void
    func setSelectedItem(item: Int) -> Void
    func get(_ pos: Int) -> any TopbarComponent
    
    func onHideRequest(_ action: @escaping () -> Void)
    func onShowRequest(_ action: @escaping () -> Void)
}
