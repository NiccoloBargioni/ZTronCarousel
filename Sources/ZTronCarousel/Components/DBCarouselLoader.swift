import Foundation
import SQLite
import ZTronDataModel
import ZTronObservation
import ZTronSerializable

public final class DBCarouselLoader: ObservableObject, Component, @unchecked Sendable, AnyDBLoader {
    public let id: String = "db loader"
    private var delegate: (any MSAInteractionsManager)? = nil {
        didSet {
            guard let delegate = delegate else { return }
            delegate.setup(or: .ignore)
        }
        
        willSet {
            self.delegate?.detach()
        }
    }
    
    private let fk: SerializableGalleryForeignKeys
    
    @Published private var galleries: [SerializedGalleryModel] = [] // mutable array of immutable objects
    @Published private var images: [ZTronCarouselImageDescriptor] = []
    
    private(set) public var lastAction: DBLoaderAction = .ready
    
    public init(with foreignKeys: SerializableGalleryForeignKeys) {
        self.fk = foreignKeys
    }
    
    public func loadFirstLevelGalleries() throws {
        try DBMS.transaction { db in
            let firstLevel = try DBMS.CRUD.readFirstLevelOfGalleriesForTool(
                for: db,
                game: self.fk.getGame(),
                map: self.fk.getMap(),
                tab: self.fk.getTab(),
                tool: self.fk.getTool()
            )
            
            guard let galleries = firstLevel[.galleries] as? [SerializedGalleryModel] else { fatalError() }
            self.galleries = galleries
            self.lastAction = .galleriesLoaded
            
            self.delegate?.pushNotification(eventArgs: .init(source: self))
            
            return .commit
        }
    }
    
    public func loadImagesForGallery(_ theGallery: String) throws {
        try DBMS.transaction { db in
            let firstLevel = try
                DBMS.CRUD.readFirstLevelMasterImagesForGallery(
                    for: db,
                    game: self.fk.getGame(),
                    map: self.fk.getMap(),
                    tab: self.fk.getTab(),
                    tool: self.fk.getTool(),
                    gallery: theGallery,
                    options: [.outlines, .boundingCircles, .variantsMetadatas]
            )
            
            
            guard let images = firstLevel[.images] as? [SerializedImageModel] else { fatalError() }
            self.images = images.enumerated().map { i, image in
                var placeables: [any PlaceableDescriptor] = []
                var outlineBoundingBox: CGRect? = nil
                
                if let outline = firstLevel[.outlines]?[i] as? SerializedOutlineModel {
                    outlineBoundingBox = outline.getBoundingBox()

                    placeables.append(PlaceableOutlineDescriptor(
                        parentImage: image.getName(),
                        outlineAssetName: outline.getResourceName(),
                        outlineBoundingBox: outline.getBoundingBox(),
                        colorHex: outline.getColorHex(),
                        opacity: outline.getOpacity(),
                        isActive: outline.isActive()
                    ))
                    
                }
                
                if let boundingCircle = firstLevel[.boundingCircles]?[i] as? SerializedBoundingCircleModel {
                    placeables.append(PlaceableBoundingCircleDescriptor(
                        parentImageID: image.getName(),
                        boundingCircle: ZTronBoundingCircle(
                            idleDiameter: boundingCircle.getIdleDiameter(),
                            normalizedCenter: boundingCircle.getNormalizedCenter()
                        ),
                        normalizedBoundingBox: outlineBoundingBox,
                        colorHex: boundingCircle.getColorHex(),
                        opacity: boundingCircle.getOpacity(),
                        isActive: boundingCircle.isActive()
                    ))
                }
                                
                let variants = (firstLevel[.variantsMetadatas]?[i] as? SerializedImageVariantsMetadataSet)?.getVariants().map {
                    return ImageVariantDescriptor(from: $0)
                }
                
                return ZTronCarouselImageDescriptor(
                    assetName: image.getName(),
                    caption: image.getDescription(),
                    placeables: placeables,
                    variants: variants,
                    master: nil
                )
            }
            
            self.lastAction = .imagesLoaded
            Task { @MainActor in
                self.delegate?.pushNotification(eventArgs: .init(source: self))
            }
            
            return .commit
        }
    }
    
    
    public func loadImageDescriptor(
        imageID: String,
        in gallery: String,
        variantDescriptor: ImageVariantDescriptor
    ) throws {
        var placeables: [any PlaceableDescriptor] = []
        var outlineBoundingBox: CGRect? = nil
        
        try DBMS.transaction { dbConnection in
            let read = try DBMS.CRUD.readImageByIDWithOptions(
                for: dbConnection,
                image: imageID,
                gallery: gallery,
                tool: self.fk.getTool(),
                tab: self.fk.getTab(),
                map: self.fk.getMap(),
                game: self.fk.getGame(),
                options: [.images, .outlines, .boundingCircles, .variantsMetadatas, .masters]
            )
            
            guard let image = read[.images]?.first as? SerializedImageModel else { fatalError() }
            
             if let outline = read[.outlines]?.first as? SerializedOutlineModel {
                 outlineBoundingBox = outline.getBoundingBox()

                 placeables.append(PlaceableOutlineDescriptor(
                     parentImage: image.getName(),
                     outlineAssetName: outline.getResourceName(),
                     outlineBoundingBox: outline.getBoundingBox(),
                     colorHex: outline.getColorHex(),
                     opacity: outline.getOpacity(),
                     isActive: outline.isActive()
                 ))
                 
             }
             

            if let boundingCircle = read[.boundingCircles]?.first as? SerializedBoundingCircleModel {
                 placeables.append(PlaceableBoundingCircleDescriptor(
                     parentImageID: image.getName(),
                     boundingCircle: ZTronBoundingCircle(
                         idleDiameter: boundingCircle.getIdleDiameter(),
                         normalizedCenter: boundingCircle.getNormalizedCenter()
                     ),
                     normalizedBoundingBox: outlineBoundingBox,
                     colorHex: boundingCircle.getColorHex(),
                     opacity: boundingCircle.getOpacity(),
                     isActive: boundingCircle.isActive()
                 ))
             }
                             
            
            let variants = (read[.variantsMetadatas]?.first as? SerializedImageVariantsMetadataSet)?.getVariants().map {
                 return ImageVariantDescriptor(from: $0)
             }
                        
            
            assert(image.getName() == variantDescriptor.getSlave() || image.getName() == variantDescriptor.getMaster())
            assert(imageID == image.getName())
            
            self.lastAction = image.getName() == variantDescriptor.getSlave() ? .variantLoadedForward : .variantLoadedBackward
            
            self.pushNotification(
                VariantLoadedEventMessage(
                    source: self,
                    parentVariantDescriptor: variantDescriptor,
                    imageDescriptor: ZTronCarouselImageDescriptor(
                        assetName: image.getName(),
                        caption: image.getDescription(),
                        placeables: placeables,
                        variants: variants,
                        master: read[.masters]?.first as? String? ?? nil
                    )
                )
            )
            
            return .commit
        }
    }
    
    
    public func getLastAction() -> DBLoaderAction {
        return self.lastAction
    }
    
    public func getGalleries() -> [SerializedGalleryModel] {
        return Array(self.galleries)
    }
    
    public func getImages() -> [ZTronCarouselImageDescriptor] {
        return Array(self.images)
    }
        
    // MARK: - COMPONENT
    public func getDelegate() -> (any ZTronObservation.InteractionsManager)? {
        return self.delegate
    }
    
    public func setDelegate(_ interactionsManager: (any ZTronObservation.InteractionsManager)?) {
        guard let interactionsManager = interactionsManager as? MSAInteractionsManager else {
            if interactionsManager != nil {
                fatalError("Expected interactions manger of type \(String(describing: MSAInteractionsManager.self)) in \(#function) @ \(#file)")
            } else {
                self.delegate = nil
                return
            }
        }
        
        self.delegate = interactionsManager
    }
    
    public static func == (lhs: DBCarouselLoader, rhs: DBCarouselLoader) -> Bool {
        return lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }
    
    deinit {
        self.delegate?.detach()
    }

    public func pushNotification(_ args: BroadcastArgs) {
        self.delegate?.pushNotification(eventArgs: args, limitToNeighbours: true) /*{
            Task(priority: .userInitiated) { @MainActor in
                self.lastAction = .ready
            }
        }*/
    }
    
}
