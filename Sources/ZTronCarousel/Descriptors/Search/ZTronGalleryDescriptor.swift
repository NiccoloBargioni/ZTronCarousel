import ZTronDataModel

public final class ZTronGalleryDescriptor: Sendable, Hashable, CustomStringConvertible, Encodable, Decodable {
    public let description: String
    
    private let name: String
    private let position: Int
    private let assetsImageName: String?
    private let tool: String
    private let tab: String
    private let map: String
    private let game: String
    private let searchToken: ZTronGallerySearchTokenDescriptor?
    private let master: String?
    private let imagesCount: Int?
    private let subgalleriesCount: Int?
    private let nestingLevel: Int?
    
    public init(
        from: SerializedGalleryModel,
        with token: SerializedSearchTokenModel?,
        master: String?,
        imagesCount: Int? = nil,
        subgalleriesCount: Int? = nil,
        nestingLevel: Int? = nil
    ) {
        self.name = from.getName()
        self.position = from.getPosition()
        self.assetsImageName = from.getAssetsImageName()
        self.tool = from.getTool()
        self.tab = from.getTab()
        self.map = from.getMap()
        self.game = from.getGame()
        
        if let token = token {
            self.searchToken = ZTronGallerySearchTokenDescriptor(from: token)
            
            assert(self.tool == token.getTool())
            assert(self.tab == token.getTab())
            assert(self.map == token.getMap())
            assert(self.game == token.getGame())
        } else {
            self.searchToken = nil
        }
        
        self.imagesCount = imagesCount
        self.subgalleriesCount = subgalleriesCount
        self.nestingLevel = nestingLevel
        
        self.master = master
        
        self.description = """
        GALLERY(
            name: \(self.name),
            position: \(self.position),
            assetsImageName: \(String(describing: self.assetsImageName)),
            master: \(String(describing: self.master))
            token: \(self.searchToken == nil ? "nil" : self.searchToken!.description),
            imagesCount: \(String(describing: self.imagesCount)),
            subgalleriesCount: \(String(describing: self.subgalleriesCount)),
            nestingLevel: \(String(describing: self.nestingLevel)),
            FOREIGN_KEYS: (
                tool: \(self.tool),
                tab: \(self.tab),
                map: \(self.map),
                game: \(self.game)
            )
        )
        """
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.description = try container.decode(String.self, forKey: .description)
        self.name = try container.decode(String.self, forKey: .name)
        self.position = try container.decode(Int.self, forKey: .position)
        self.assetsImageName = try container.decode(String?.self, forKey: .assetsImageName)
        self.imagesCount = try container.decode(Int?.self, forKey: .imagesCount)
        self.subgalleriesCount = try container.decode(Int?.self, forKey: .subgalleriesCount)
        self.nestingLevel = try container.decode(Int?.self, forKey: .nestingLevel)
        self.tool = try container.decode(String.self, forKey: .tool)
        self.tab = try container.decode(String.self, forKey: .tab)
        self.map = try container.decode(String.self, forKey: .map)
        self.game = try container.decode(String.self, forKey: .game)
        self.searchToken = try container.decode(ZTronGallerySearchTokenDescriptor?.self, forKey: .searchToken)
        self.master = try container.decode(String?.self, forKey: .master)
    }
    
    enum CodingKeys: String, CodingKey {
        case description
        case name
        case position
        case assetsImageName
        case imagesCount
        case subgalleriesCount
        case nestingLevel
        case tool
        case tab
        case map
        case game
        case searchToken
        case master
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.description, forKey: .description)
        try container.encode(self.name, forKey: .name)
        try container.encode(self.position, forKey: .position)
        try container.encode(self.assetsImageName, forKey: .assetsImageName)
        try container.encode(self.imagesCount, forKey: .imagesCount)
        try container.encode(self.subgalleriesCount, forKey: .subgalleriesCount)
        try container.encode(self.nestingLevel, forKey: .nestingLevel)
        try container.encode(self.tool, forKey: .tool)
        try container.encode(self.tab, forKey: .tab)
        try container.encode(self.map, forKey: .map)
        try container.encode(self.game, forKey: .game)
        try container.encode(self.searchToken, forKey: .searchToken)
        try container.encode(self.master, forKey: .master)
    }

    
    public func getName() -> String {
        return self.name
    }
        
    public func getPosition() -> Int {
        return self.position
    }
    
    public func getAssetsImageName() -> String? {
        return self.assetsImageName
    }
    
    public func getImagesCount() -> Int? {
        return self.imagesCount
    }
    
    public func getSubgalleriesCount() -> Int? {
        return self.subgalleriesCount
    }
        
    public func getNestingLevel() -> Int? {
        return self.nestingLevel
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
    
    public func getSearchToken() -> ZTronGallerySearchTokenDescriptor? {
        return self.searchToken // immutable anyway
    }
    
    public func getMaster() -> String? {
        return self.master
    }
    
    public static func == (lhs: ZTronGalleryDescriptor, rhs: ZTronGalleryDescriptor) -> Bool {
        return lhs.name == rhs.name && lhs.position == rhs.position && lhs.master == rhs.master && lhs.tool == rhs.tool && lhs.tab == rhs.tab && lhs.map == rhs.map && lhs.game == rhs.game
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.name)
        hasher.combine(self.tool)
        hasher.combine(self.tab)
        hasher.combine(self.game)
    }
    
}
