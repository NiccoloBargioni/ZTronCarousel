import ZTronDataModel

public final class ZTronGallerySearchTokenDescriptor: Sendable, CustomStringConvertible, Encodable, Decodable {
    public let description: String
    
    private let title: String
    private let icon: String
    private let iconColorHex: String
    
    private let gallery: String
    private let tool: String
    private let tab: String
    private let map: String
    private let game: String
    
    enum CodingKeys: String, CodingKey {
        case description
        case title
        case icon
        case iconColorHex
        case gallery
        case tool
        case tab
        case map
        case game
    }
    
    public init(from: SerializedSearchTokenModel) {
        self.title = from.getTitle()
        self.icon = from.getIcon()
        self.iconColorHex = from.getIconColorHex()
        
        assert(self.iconColorHex.isHexColor)
        
        self.gallery = from.getGallery()
        self.tool = from.getTool()
        self.tab = from.getTab()
        self.map = from.getMap()
        self.game = from.getGame()
        
        self.description = """
        GALLERY_SEARCH_TOKEN(
            title: \(self.title),
            icon: \(self.icon),
            iconColorHex: \(self.iconColorHex),
            FOREIGN_KEYS: (
                gallery: \(self.gallery),
                tool: \(self.tool),
                tab: \(self.tab),
                map: \(self.map),
                game: \(self.game)
            )
        )
        """
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.description, forKey: .description)
        try container.encode(self.title, forKey: .title)
        try container.encode(self.icon, forKey: .icon)
        try container.encode(self.iconColorHex, forKey: .iconColorHex)
        try container.encode(self.gallery, forKey: .gallery)
        try container.encode(self.tool, forKey: .tool)
        try container.encode(self.tab, forKey: .tab)
        try container.encode(self.map, forKey: .map)
        try container.encode(self.game, forKey: .game)
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.description = try container.decode(String.self, forKey: .description)
        self.title = try container.decode(String.self, forKey: .title)
        self.icon = try container.decode(String.self, forKey: .icon)
        self.iconColorHex = try container.decode(String.self, forKey: .iconColorHex)
        self.gallery = try container.decode(String.self, forKey: .gallery)
        self.tool = try container.decode(String.self, forKey: .tool)
        self.tab = try container.decode(String.self, forKey: .tab)
        self.map = try container.decode(String.self, forKey: .map)
        self.game = try container.decode(String.self, forKey: .game)
    }
    public func getTitle() -> String {
        return self.title
    }
    
    public func getIcon() -> String {
        return self.icon
    }
    
    public func getIconColorHex() -> String {
        return self.iconColorHex
    }
    
    public func getGallery() -> String {
        return self.gallery
    }
    
    public func getTool() -> String {
        return self.tool
    }
    
    public func getTab() -> String {
        return self.tab
    }
    
    public func getMap() -> String {
        return self.map
    }
    
    public func getGame() -> String {
        return self.game
    }
}
