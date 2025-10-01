import Testing
import ZTronSerializable
import ZTronDataModel
import ZTronObservation
@testable import ZTronCarousel


#if DEBUG
public final class MockDBLoader: AnyDBLoader {
    public var id: String = "mock db loader"
    private var depth: Int = 0
    private var delegate: (any MSAInteractionsManager)? = nil
    private(set) var galleries: [SerializedGalleryModel] = []
    
    public var fk: ZTronSerializable.SerializableGalleryForeignKeys = .init(
        tool: "bo4.vod.side.quests.shield.upgrade.tool.name",
        tab: "side quests",
        map: "voyage of despair",
        game: "black ops 4"
    )
    public var lastAction: ZTronCarousel.DBLoaderAction = .ready
        
    
    public func setCurrentDepth(_ depth: Int) {
        self.depth = depth
    }
    
    public func getCurrentDepth() -> Int {
        return self.depth
    }
    
    public func loadFirstLevelGalleries(_ master: String?) throws {
        self.lastAction = .galleriesLoaded

        guard let master = master else {
            self.galleries = DBMockup.Gallery.rootGalleries
            self.delegate?.pushNotification(
                eventArgs: GalleriesLoadedEventMessage(
                    source: self,
                    galleries: DBMockup.Gallery.rootGalleries.map({ galleryModel in
                        ZTronGalleryDescriptor(
                            from: galleryModel,
                            with: nil,
                            master: nil
                        )
                    })
                )
            )
            
            return
        }
        
        switch master {
            case "bo4.vod.easter.egg.shield.upgrade.bones":
            self.galleries = DBMockup.Gallery.bonesSubgalleries

            self.delegate?.pushNotification(
                eventArgs: GalleriesLoadedEventMessage(
                    source: self,
                    galleries: DBMockup.Gallery.bonesSubgalleries.map({ galleryModel in
                        ZTronGalleryDescriptor(
                            from: galleryModel,
                            with: nil,
                            master: "bo4.vod.easter.egg.shield.upgrade.bones"
                        )
                    })
                )
            )
            
            default:
                break
        }
    }
    
    public func loadImagesForGallery(_ theGallery: String?) throws {
        
    }
    
    public func loadGalleriesGraph() throws {
        
    }
    
    public func loadImagesForSearch() throws {
        
    }
    
    public func loadImageDescriptor(imageID: String, in gallery: String, variantDescriptor: ZTronCarousel.ImageVariantDescriptor) throws {
        
    }
    
    
    public func getDelegate() -> (any ZTronObservation.InteractionsManager)? {
        return self.delegate
    }
    
    public func setDelegate(_ interactionsManager: (any InteractionsManager)?) {
        self.delegate = interactionsManager as? (any MSAInteractionsManager)
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }
    
    public static func == (lhs: MockDBLoader, rhs: MockDBLoader) -> Bool {
        return true
    }
}

@Test func testMockDBLoaderGalleries() async throws {
    let loader = MockDBLoader()
    
    try? loader.loadFirstLevelGalleries("bo4.vod.easter.egg.shield.upgrade.bones")
    #expect(loader.galleries.count == 4)
}

#endif
