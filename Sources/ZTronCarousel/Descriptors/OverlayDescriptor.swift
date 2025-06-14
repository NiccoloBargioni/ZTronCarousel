import Foundation

public protocol OverlayDescriptor: AnyObject, Sendable {
    var descriptorType: OverlayDescriptorType { get }
}


public struct OverlayDescriptorType: RawRepresentable, Sendable, Hashable {
    public init?(rawValue: String) {
        self.rawValue = rawValue
    }
    
    public var rawValue: String
    
    public typealias RawValue = String

    public static let any = "overlay"
}
