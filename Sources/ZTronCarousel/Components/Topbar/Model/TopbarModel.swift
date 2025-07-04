import Foundation
import ZTronObservation


public final class TopbarModel : ObservableObject, Component, AnyTopbarModel {
    public let id: String
    private var delegate: (any MSAInteractionsManager)? = nil {
        willSet {
            guard let delegate = self.delegate else { return }
            delegate.detach()
        }
    
        didSet {
            guard let delegate = self.delegate else { return }
            delegate.setup(or: .ignore)
        }
    }
    
    public let title: String
    
    @Published private var selectedItem: Int {
        didSet {
            self.selectedItemChangedAction?(self.selectedItem)
        }
    }
    
    @Published private var items: [any TopbarComponent] {
        didSet {
            self.itemsChangedAction?(self.items)
        }
    }
    
    @Published private(set) public var redacted: Bool = true {
        didSet {
            self.redactedChangedAction?(self.redacted)
        }
    }
    
    private(set) public var lastAction: TopbarAction = .selectedItemChanged
    
    private var selectedItemChangedAction: ((Int) -> Void)? = nil
    private var itemsChangedAction: (([any TopbarComponent]) -> Void)? = nil
    private var redactedChangedAction: ((Bool) -> Void)? = nil
    
    public init(items: [TopbarItem], title: String, selectedItem: Int = 0) {
        self.items = items
        self.title = title
        self.selectedItem = selectedItem
        self.id = "\(title) topbar"
    }
    
    public func count() -> Int {
        return self.items.count
    }
    
    public func get(_ pos: Int) -> any TopbarComponent {
        assert(pos >= 0 && pos < self.items.count)
        return self.items[pos]
    }
    
    public func setSelectedItem(item: Int) {
        assert(item >= 0 && item < self.items.count)
        self.selectedItem = item
        self.lastAction = .selectedItemChanged
        self.delegate?.pushNotification(eventArgs: .init(source: self))
    }
    
    public func getSelectedItem() -> Int {
        return self.selectedItem
    }
    
    public func getSelectedItemName() -> String {
        return self.items[self.selectedItem].getName()
    }
    
    public func switchTo(itemNamed: String) {
        if let requestedItemIndex = (self.items.firstIndex {
            return $0.getName() == itemNamed
        }) {
            self.selectedItem = requestedItemIndex
            self.lastAction = .selectedItemChanged
            self.pushNotification()
        }
    }
    
    func getTitle() -> String {
        return self.title
    }
    
    public func getDelegate() -> (any ZTronObservation.InteractionsManager)? {
        return self.delegate
    }
    
    public func replaceItems(with items: [any TopbarComponent]) {
        self.selectedItem = 0
        self.items = items
        self.lastAction = .itemsReplaced
        
        self.delegate?.pushNotification(eventArgs: .init(source: self))
    }
    
    // MARK: - Component
    public func setDelegate(_ interactionsManager: (any ZTronObservation.InteractionsManager)?) {
        guard let interactionsManager = interactionsManager as? MSAInteractionsManager else {
            if interactionsManager == nil {
                self.delegate = nil
            } else {
                fatalError("Please provide a delegate of type MSAInteractionsManager")
            }
            
            return
        }
        
        self.delegate = interactionsManager
    }

    public static func == (lhs: TopbarModel, rhs: TopbarModel) -> Bool {
        return lhs.items.count == rhs.items.count && lhs.items.enumerated().reduce(true, { equalsUntilNow, item in
            item.element === rhs.items[item.offset]
        }) && lhs.title == rhs.title && lhs.selectedItem == rhs.selectedItem
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(title)
    }
    
    public func setIsRedacted(to isRedacted: Bool) {
        self.redacted = isRedacted
    }
    
    deinit {
        self.delegate?.detach()
    }
    
    
    public final func onRedactedChange(_ action: @escaping (Bool) -> Void) {
        self.redactedChangedAction = action
    }
    
    public final func onSelectedItemChanged(_ action: @escaping (Int) -> Void) {
        self.selectedItemChangedAction = action
    }
    
    public final func onItemsReplaced(_ action: @escaping ([any TopbarComponent]) -> Void) {
        self.itemsChangedAction = action
    }
}

public enum TopbarAction {
    case selectedItemChanged
    case itemsReplaced
    case loadSubgallery
    case subgalleriesLoaded
}
