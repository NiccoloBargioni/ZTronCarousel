import Foundation

public final class TopbarItem: TopbarComponent {
    private let icon: String
    private let name: String
    
    public init(icon: String, name: String) {
        self.icon = icon
        self.name = name
    }
    
    public func getIcon() -> String {
        return self.icon
    }
    
    public func getName() -> String {
        return self.name
    }
    
    public static func == (lhs: TopbarItem, rhs: TopbarItem) -> Bool {
        return lhs.icon == rhs.icon && lhs.name == rhs.name
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.icon)
        hasher.combine(self.name)
    }
}
