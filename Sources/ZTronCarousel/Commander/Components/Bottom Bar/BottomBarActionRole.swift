import Foundation

public enum BottomBarActionRole: String, Hashable, Sendable {
    case outline 
    case boundingCircle
    case fullScreen
    case triangulate
    case caption
    case colorPicker
    case variant
    
    public static func fromBottomBarAction(_ action: BottomBarLastAction) -> Self? {
        switch action {
            case .toggleOutline:
                return .outline
                
            case .toggleBoundingCircle:
                return .boundingCircle
                
            case .tappedToggleCaption:
                return .caption
                
            default:
                return nil
        }
    }
}
