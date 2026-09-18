import Foundation

/// Identifies a piece of bottom-bar content that can be locked behind a paywall.
///
/// Mirrors `BottomBarActionRole`, with one addition: variant roles can be matched either
/// individually — through the variant's slave image name — or as a whole family through
/// ``anyVariant``. This makes variants gateable from static configuration, without having to
/// construct an `ImageVariantDescriptor` up front.
public enum PaywalledContent: Hashable, Sendable {
    case outline
    case boundingCircle
    case fullScreen
    case triangulate
    case caption
    case colorPicker
    case backToPreviousVariant
    
    /// Matches every `.variant(_)` role, regardless of the specific descriptor.
    case anyVariant
    
    /// Matches the `.variant(_)` role whose descriptor's slave image name equals the associated value.
    case variant(String)
    
    /// Whether this content identifier matches `role`.
    public func matches(_ role: BottomBarActionRole) -> Bool {
        switch (self, role) {
            case (.outline, .outline),
                 (.boundingCircle, .boundingCircle),
                 (.fullScreen, .fullScreen),
                 (.triangulate, .triangulate),
                 (.caption, .caption),
                 (.colorPicker, .colorPicker),
                 (.backToPreviousVariant, .backToPreviousVariant):
                return true
                
            case (.anyVariant, .variant(_)):
                return true
                
            case (.variant(let slave), .variant(let descriptor)):
                return descriptor.getSlave() == slave
                
            default:
                return false
        }
    }
}

public extension Collection where Element == PaywalledContent {
    /// Whether any content identifier in this collection matches `role`.
    func matches(_ role: BottomBarActionRole) -> Bool {
        return self.contains { $0.matches(role) }
    }
}
