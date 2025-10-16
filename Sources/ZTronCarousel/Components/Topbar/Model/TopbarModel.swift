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
    private let depth: Int
    
    public var selectedItemStrategy: TopbarItemStrategy {
        if self.selectedItem < self.items.count {
            return self.items[self.selectedItem].strategy
        } else {
            return .passthrough(depth: depth)
        }
    }

    @Published private var selectedItem: Int {
        didSet {
            self.selectedItemChangedAction?(self.selectedItem)
        }
    }
    
    private var selectedComponent: any TopbarComponent {
        return self.items[self.selectedItem]
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
    
    private var onHideAction: (() -> Void)? = nil
    private var onShowAction: (() -> Void)? = nil
    
    public init(
        items: [TopbarItem],
        title: String,
        selectedItem: Int = 0,
        depth: Int = 0
    ) {
        self.items = items
        self.title = title
        self.selectedItem = selectedItem
        self.id = "\(title) topbar \(depth)"
        self.depth = depth
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
        if self.selectedItemStrategy == .leaf {
            self.lastAction = .selectedItemChanged
            self.delegate?.pushNotification(eventArgs: .init(source: self))
        } else {
            self.lastAction = .loadSubgallery
            self.delegate?.pushNotification(
                eventArgs: LoadSubgalleryRequestEventMessage(
                    source: self,
                    master: self.selectedComponent.getName()
                ),
            )
        }
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
            
            if self.selectedItemStrategy == .leaf {
                self.lastAction = .selectedItemChanged
                self.pushNotification()
            } else {
                self.lastAction = .loadSubgallery
                self.delegate?.pushNotification(
                    eventArgs: LoadSubgalleryRequestEventMessage(
                        source: self,
                        master: self.selectedComponent.getName()
                    ),
                )
            }
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
        
        if self.selectedItemStrategy == .leaf {
            self.lastAction = .itemsReplaced
            self.delegate?.pushNotification(eventArgs: .init(source: self))
        } else {
            self.lastAction = .loadSubgallery
            self.delegate?.pushNotification(
                eventArgs: LoadSubgalleryRequestEventMessage(
                    source: self,
                    master: self.selectedComponent.getName()
                ),
            )
        }
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
    
    public final func getDepth() -> Int {
        return self.depth
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
    
    public final func onHideRequest(_ action: @escaping () -> Void) {
        self.onHideAction = action
    }
    
    public final func onShowRequest(_ action: @escaping () -> Void) {
        self.onShowAction = action
    }
    
    public final func hide() {
        self.onHideAction?()
    }
    
    public final func show() {
        self.onShowAction?()
    }
}

public enum TopbarAction {
    case selectedItemChanged
    case itemsReplaced
    case loadSubgallery
    case subgalleriesLoaded
}
