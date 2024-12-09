import ZTronDataModel
import Ifrit

public final class SearchableImage: Sendable, Searchable {
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
        
        self.localizedName = String(localized: String.LocalizationValue(stringLiteral: self.name), bundle: .main)
        self.localizedDescription = String(localized: String.LocalizationValue(stringLiteral: self.description), bundle: .main)
        if let searchLabel = self.searchLabel {
            self.localizedSearchLabel = String(localized: String.LocalizationValue(stringLiteral: searchLabel), bundle: .main)
        } else {
            self.localizedSearchLabel = nil
        }
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

}
