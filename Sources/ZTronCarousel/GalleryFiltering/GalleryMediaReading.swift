import Foundation
import SQLite
import ZTronDataModel
import ZTronCarouselCore

/// A read-only, side-effect-free source of media descriptors for a gallery.
///
/// Unlike `AnyDBLoader.loadImagesForGallery(_:)`, implementations must not mutate any state
/// (no `lastAction`, no depth bookkeeping) nor push notifications on the mediator: this is what
/// allows `GalleryFilteringCoordinator` to peek into *sibling* galleries — to decide which routing
/// elements to disable — without disturbing the carousel currently on screen.
public protocol GalleryMediaReading: AnyObject, Sendable {
    /// The media descriptors of the first level of `gallery` (`nil` for the tool's root gallery),
    /// mapped exactly like `DBCarouselLoader.loadImagesForGallery(_:)` maps them, so that filter
    /// predicates evaluate identically on both paths.
    func readMediaDescriptorsForGallery(_ gallery: String?) throws -> [any ZTronVisualMediaDescriptor]
}

// MARK: - DBCarouselLoader conformance

/// Purely additive retroactive conformance: `DBCarouselLoader` itself is not modified.
///
/// The mapping below intentionally replicates, line by line, the one inside
/// `DBCarouselLoader.loadImagesForGallery(_:)` — minus the notification push, the `lastAction`
/// mutation and the depth bookkeeping — so both produce indistinguishable descriptors. The only
/// behavioral divergence is on malformed rows: `loadImagesForGallery` traps, while this method
/// returns an empty array (a background sibling probe must never crash the app).
extension DBCarouselLoader: GalleryMediaReading {
    public func readMediaDescriptorsForGallery(_ gallery: String?) throws -> [any ZTronVisualMediaDescriptor] {
        var result: [any ZTronVisualMediaDescriptor] = []
        
        try DBMS.transaction { db in
            let firstLevel = try
                CRUD.readFirstLevelMasterImagesForGallery(
                    for: db,
                    game: self.fk.getGame(),
                    map: self.fk.getMap(),
                    tab: self.fk.getTab(),
                    tool: self.fk.getTool(),
                    gallery: gallery,
                    options: [.outlines, .boundingCircles, .variantsMetadatas]
            )
            
            guard let fetchedMedias = firstLevel[.medias] as? [any SerializedVisualMediaModel] else {
                #if DEBUG
                print("GalleryMediaReading: unable to decode the medias of gallery \(gallery ?? "<root>"). Returning an empty set.")
                #endif
                return .commit
            }
            
            result = fetchedMedias.enumerated().map { i, media in
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
            
            return .commit
        }
        
        return result
    }
}
