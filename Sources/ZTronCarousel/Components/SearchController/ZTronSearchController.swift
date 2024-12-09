import Foundation
import SwiftGraph
import ZTronObservation
import ZTronDataModel
import Ifrit

public final class ZTronSearchController: AnySearchController, ObservableObject, @unchecked Sendable {
    @InteractionsManaging private var delegate: (any MSAInteractionsManager)? = nil
    private let fuse: Fuse
    
    @Published private var searchResults: [SearchableImage] = []
    
    private(set) public var lastAction: SearchControllerAction = .ready
    public let id: String = "search controller"
    
    private var galleriesGraph: UnweightedGraph<ZTronGalleryDescriptor>? = nil
    private var images: [SearchableImage] = []
    
    public init(fuse: Fuse) {
        self.fuse = fuse
    }
    
    public static func == (lhs: ZTronSearchController, rhs: ZTronSearchController) -> Bool {
        return lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.id)
    }
    
    public func prepare() {
        self.lastAction = .loadGalleriesGraph
        self.pushNotification()
    }
    
    
    public func galleriesLoaded(_ galleries: SwiftGraph.UnweightedGraph<ZTronGalleryDescriptor>) {
        self.galleriesGraph = galleries
        self.lastAction = .loadAllMasterImages
        self.pushNotification()
    }
    
    public func imagesLoaded(_ images: [SearchableImage]) {
        self.images = images
    }
    
    public func selectedImage(_ image: SearchableImage) {
        guard let galleriesGraph = self.galleriesGraph else { return }
        guard let indexOfGallery = (galleriesGraph.firstIndex { gallery in
            return gallery.getName() == image.getGallery()
        }) else {
            return
        }
        
        let reversedGraph = galleriesGraph.reversed()
        
        let pathToIndex = reversedGraph.bfs(fromIndex: indexOfGallery) { gallery in
            if let indexOfGallery = galleriesGraph.indexOfVertex(gallery) {
                return galleriesGraph.indegreeOfVertex(at: indexOfGallery) == 0
            } else {
                return false
            }
        }
        
        var galleryPath: [ZTronGalleryDescriptor] = []
        if let firstEdge = pathToIndex.first {
            galleryPath.append(galleriesGraph[firstEdge.u])
            
            pathToIndex.forEach { edge in
                galleryPath.append(galleriesGraph[edge.v])
            }
        } else {
            galleryPath.append(galleriesGraph[indexOfGallery])
        }
        
        assert(galleryPath.last === galleriesGraph[indexOfGallery])
        
        self.lastAction = .imageSelected
        self.getDelegate()?.pushNotification(
            eventArgs: ImageSelectedFromSearchEventMessage(
                source: self,
                galleryPath: galleryPath,
                selectedImage: image
            ),
            limitToNeighbours: true
        )
    }
    
    nonisolated public func search(text: String) async {
        let searchResults = await self.fuse.search(text, in: self.images, by: \.propertiesCustomWeight)
        
        let matchingImages = searchResults.map {
            return self.images[$0.index]
        }
        
        await MainActor.run {
            self.searchResults = matchingImages
        }
    }
    
    public func getSearchResults() -> [SearchableImage] {
        return Array(self.searchResults)
    }
    
    public func searchCancelled() {
        self.lastAction = .cancelled
        self.pushNotification()
    }
    
    public func getDelegate() -> (any ZTronObservation.InteractionsManager)? {
        return self.delegate
    }
    
    public func setDelegate(_ interactionsManager: (any ZTronObservation.InteractionsManager)?) {
        self.delegate = interactionsManager as? MSAInteractionsManager
    }
}
