import Foundation

public enum BottomBarActionRole: Hashable, Sendable {
    case outline 
    case boundingCircle
    case fullScreen
    case triangulate
    case caption
    case colorPicker
    case variant(ImageVariantDescriptor)
    case backToPreviousVariant
    
    public static func fromBottomBarAction(_ action: BottomBarLastAction) -> Self? {
        switch action {
            case .toggleOutline:
                return .outline
                
            case .toggleBoundingCircle:
                return .boundingCircle
                
            case .tappedToggleCaption:
                return .caption
                
            case .tappedVariantChange(let variant):
                return .variant(variant)
            
            case .tappedGoBack:
                return .backToPreviousVariant
            
            default:
                return nil
        }
    }
}
