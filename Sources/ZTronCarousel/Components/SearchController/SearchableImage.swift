import ZTronDataModel
import Ifrit

public final class SearchableImage: Sendable, Searchable, Hashable, Identifiable {
    public let id: String
    private let name: String
    private let description: String
    private let position: Int
    private let searchLabel: String?
    private let gallery: String
    
    private let localizedName: String
    private let localizedDescription: String
    private let localizedSearchLabel: String?
    
    public var propertiesCustomWeight: [FuseProp] {
        if let searchLabel = self.localizedSearchLabel {
            return [
                FuseProp(searchLabel, weight: 0.75),
                FuseProp(self.localizedDescription, weight: 0.25)
            ]
        } else {
            return [
                FuseProp(self.localizedDescription, weight: 0.9),
                FuseProp(self.localizedName, weight: 0.1)
            ]
        }
    }

    
    public init(from: SerializedImageModel) {
        self.name = from.getName()
        self.description = from.getDescription()
        self.position = from.getPosition()
        self.searchLabel = from.getSearchLabel()
        self.gallery = from.getGallery()
        
        self.localizedName = self.name.localized(in: .main)
        self.localizedDescription = self.description.localized(in: .main)
        if let searchLabel = self.searchLabel {
            self.localizedSearchLabel = searchLabel.localized(in: .main)
        } else {
            self.localizedSearchLabel = nil
        }
        
        self.id = self.name
    }
    
    
    public func getName() -> String {
        return self.name
    }
    
    public func getDescription() -> String {
        return self.description
    }
    
    public func getPosition() -> Int {
        return self.position
    }
    
    public func getSearchLabel() -> String? {
        return self.searchLabel
    }
    
    public func getGallery() -> String {
        return self.gallery
    }

    public static func == (lhs: SearchableImage, rhs: SearchableImage) -> Bool {
        return lhs.name == rhs.name && lhs.gallery == rhs.gallery && lhs.description == rhs.description && lhs.position == rhs.position
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(gallery)
        hasher.combine(description)
        hasher.combine(position)
    }
}
