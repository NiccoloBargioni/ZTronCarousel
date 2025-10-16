import Foundation
import SQLite
import SwiftGraph
import ZTronDataModel
import ZTronObservation
import ZTronSerializable

public final class DBCarouselLoader: ObservableObject, Component, @unchecked Sendable, AnyDBLoader {
    public let id: String = "db loader"
    @InteractionsManaging(setupOr: .ignore, detachOr: .fail) private var delegate: (any MSAInteractionsManager)? = nil
    public let fk: SerializableGalleryForeignKeys
    
    private(set) public var lastAction: DBLoaderAction = .ready
    private var currentDepth: Int = 0
    
    public init(with foreignKeys: SerializableGalleryForeignKeys) {
        self.fk = foreignKeys
    }
    
    public func loadFirstLevelGalleries(_ master: String? = nil) throws {
        try DBMS.transaction { db in
            let firstLevel =
                master != nil ?
            try DBMS.CRUD.readFirstLevelOfSubgalleriesForGallery(
                for: db,
                game: self.fk.getGame(),
                map: self.fk.getMap(),
                tab: self.fk.getTab(),
                tool: self.fk.getTool(),
                gallery: master!,
                options: [.imagesCount, .subgalleriesCount, .nestingLevel]
            ) :
            try DBMS.CRUD.readFirstLevelOfGalleriesForTool(
                for: db,
                game: self.fk.getGame(),
                map: self.fk.getMap(),
                tab: self.fk.getTab(),
                tool: self.fk.getTool(),
                options: [.imagesCount, .subgalleriesCount, .nestingLevel]
            )
            
            guard let galleries = firstLevel[.galleries] as? [SerializedGalleryModel] else { fatalError() }
            self.lastAction = .galleriesLoaded
            
            self.currentDepth += 1
            self.delegate?.pushNotification(
                eventArgs: GalleriesLoadedEventMessage(
                    source: self,
                    galleries: galleries.enumerated().map({ i, galleryModel in
                        return ZTronGalleryDescriptor(
                            from: galleryModel,
                            with: nil,
                            master: master,
                            imagesCount: (firstLevel[.imagesCount] as? [Int])?[i] ?? nil,
                            subgalleriesCount: (firstLevel[.subgalleriesCount] as? [Int])?[i] ?? nil,
                            nestingLevel: (firstLevel[.nestingLevel] as? [Int])?[i] ?? nil
                        )
                    })
                )
            )
            
            return .commit
        }
    }
    
    public func loadImagesForGallery(_ theGallery: String?) throws {
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
            
            
            guard let fetchedMedias = firstLevel[.medias] as? [any SerializedVisualMediaModel] else { fatalError() }
            let processedMedias: [any ZTronVisualMediaDescriptor] = fetchedMedias.enumerated().map { i, media in
                var placeables: [any PlaceableDescriptor] = []
                var outlineBoundingBox: CGRect? = nil
                
                if let outline = firstLevel[.outlines]?[i] as? SerializedOutlineModel {
                    outlineBoundingBox = outline.getBoundingBox()

                    placeables.append(PlaceableOutlineDescriptor(
                        parentImage: media.getName(),
                        outlineAssetName: outline.getResourceName(),
                        outlineBoundingBox: outline.getBoundingBox(),
                        colorHex: outline.getColorHex(),
                        opacity: outline.getOpacity(),
                        isActive: outline.isActive()
                    ))
                    
                }
                
                if let boundingCircle = firstLevel[.boundingCircles]?[i] as? SerializedBoundingCircleModel {
                    placeables.append(PlaceableBoundingCircleDescriptor(
                        parentImageID: media.getName(),
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
                
                switch media.getType() {
                case .image:
                    return ZTronCarouselImageDescriptor(
                        assetName: media.getName(),
                        caption: media.getDescription(),
                        placeables: placeables,
                        variants: variants,
                        master: nil
                    )
                case .video:
                    guard let video = media as? SerializedVideoModel else { fatalError("Unexpectedly found .video type on non-video serialized media. Aborting") }
                    return ZTronCarouselVideoDescriptor(
                        assetName: video.getName(),
                        extension: video.getExtension(),
                        caption: video.getDescription()
                    )
                    
                @unknown default:
                    fatalError("Please update the code in \(#file)@\(#line) in \(#function) to accomodate for the added media types")
                }
            }
            
            let depth = theGallery != nil ? try DBMS.CRUD.readGalleryNestingDepth(
                for: db,
                game: self.fk.getGame(),
                map: self.fk.getMap(),
                tab: self.fk.getTab(),
                tool: self.fk.getTool(),
                gallery: theGallery!
            ) ?? 0 : 0
            
            self.lastAction = .imagesLoaded
            self.delegate?.pushNotification(
                eventArgs: MediasLoadedEventMessage(
                    source: self,
                    medias: processedMedias,
                    depth: depth
                )
            )
            
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
                options: [.medias, .outlines, .boundingCircles, .variantsMetadatas, .masters]
            )
            
            guard let image = read[.medias]?.first as? any SerializedVisualMediaModel else { fatalError() }
            
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
    
    public final func loadGalleriesGraph() throws -> Void {
        var allGalleries: [ReadGalleryOption: [(any ReadGalleryOptional)?]] = [:]
        
        try DBMS.transaction { db in
            allGalleries = try DBMS.CRUD.readAllGalleriesForTool(
                for: db,
                tool: self.fk.getTool(),
                tab: self.fk.getTab(),
                map: self.fk.getMap(),
                game: self.fk.getGame(),
                options: [.galleries, .searchToken, .master]
            )
            
            return .commit
        }
        
        var galleryIDMap: [String: ZTronGalleryDescriptor] = [:]
        
        if let theGalleries = (allGalleries[.galleries]?.map {
            return ($0 as! SerializedGalleryModel)
        }.enumerated().map { i, gallery in
            if let token = allGalleries[.searchToken]?[i] as? SerializedSearchTokenModel {
                return ZTronGalleryDescriptor(
                    from: gallery,
                    with: token,
                    master: allGalleries[.master]?[i] as? String ?? nil
                )
            } else {
                return ZTronGalleryDescriptor(
                    from: gallery,
                    with: nil,
                    master: allGalleries[.master]?[i] as? String ?? nil
                )
            }
        }) {
            theGalleries.forEach { gallery in
                galleryIDMap[gallery.getName()] = gallery
            }
            
            let galleriesGraph: UnweightedGraph<ZTronGalleryDescriptor> = UnweightedGraph()
            
            galleryIDMap.keys.forEach { galleryName in
                let _ = galleriesGraph.addVertex(galleryIDMap[galleryName]!)
            }
            
            galleryIDMap.keys.forEach { galleryName in
                if let theGallery = galleryIDMap[galleryName] {
                    if let master = theGallery.getMaster() {
                        if let masterGalleryDescriptor = galleryIDMap[master] {
                            if let indexOfGallery = galleriesGraph.indexOfVertex(theGallery),
                               let indexOfMaster = galleriesGraph.indexOfVertex(masterGalleryDescriptor) {
                                
                                galleriesGraph.addEdge(
                                    UnweightedEdge(
                                        u: indexOfMaster,
                                        v: indexOfGallery,
                                        directed: true
                                    ),
                                    directed: true
                                )
                            }
                        }
                    }
                }
            }
            
            self.lastAction = .loadedGalleriesGraph
            
            Task(priority: .userInitiated) { @MainActor in
                self.pushNotification(
                    GalleriesGraphLoadedEventMessage(
                        source: self,
                        galleries: galleriesGraph
                    )
                )
            }
        }

    }
    
    
    public func loadImagesForSearch() throws {
        var result: [ReadImageOption: [(any ReadImageOptional)?]] = [:]
        
        try DBMS.transaction { db in
            
            result = try DBMS.CRUD.readFirstLevelMasterImagesForGallery(
                for: db,
                game: self.fk.getGame(),
                map: self.fk.getMap(),
                tab: self.fk.getTab(),
                tool: self.fk.getTool(),
                gallery: nil,
                options: [.medias]
            )
            
            return .commit
        }
        
        if let images = result[.medias] as? [SerializedImageModel] {
            self.lastAction = .imagesLoadedForSearch
            
            DispatchQueue.main.async { @MainActor in
                self.pushNotification(ImagesLoadedForSearchEventMessage(source: self, images: images))
            }
        }
    }
    
    public func getLastAction() -> DBLoaderAction {
        return self.lastAction
    }
            
    public final func setCurrentDepth(_ depth: Int) {
        self.currentDepth = depth
    }
    
    public final func getCurrentDepth() -> Int {
        return self.currentDepth
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
        self.delegate?.pushNotification(eventArgs: args, limitToNeighbours: true)
    }
    
}
