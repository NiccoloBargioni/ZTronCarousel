import Foundation

public protocol PlaceableDescriptor: Sendable {
    var descriptorType: PlaceableDescriptorType { get }
}

public struct PlaceableDescriptorType: RawRepresentable, Sendable {
    public init?(rawValue: String) {
        self.rawValue = rawValue
    }
    
    public var rawValue: String
    
    public typealias RawValue = String
    
    public static let outline = "outline"
    public static let boundingCircle = "bounding circle"
}

