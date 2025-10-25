import Foundation
import ZTronObservation
import ZTronCarouselCore
import ZTronDataModel
 
public final class DBLoaderInteractionsManager: MSAInteractionsManager, @unchecked Sendable {
    weak private var owner: (any AnyDBLoader)?
    weak private var mediator: MSAMediator?
    
    private var currentGalleryName: String? = nil
    private var acknowledgedTopbar: Bool = false
    private var currentImage: String? = nil
    
    public init(owner: (any AnyDBLoader), mediator: MSAMediator) {
        self.owner = owner
        self.mediator = mediator
    }
    
    public func pushNotification(eventArgs: BroadcastArgs, limitToNeighbours: Bool = false, completion: (() -> Void)? = nil) {
        self.mediator?.pushNotification(eventArgs: eventArgs, limitToNeighbours: limitToNeighbours, completion: completion)
    }
    
    public func peerDiscovered(eventArgs: ZTronObservation.BroadcastArgs) {
        guard let owner = self.owner else { return }
        if let topbar = eventArgs.getSource() as? (any AnyTopbarModel) {
            self.mediator?.signalInterest(owner, to: topbar, or: .ignore)
            self.acknowledgedTopbar = true
        } else {
            if let colorPicker = eventArgs.getSource() as? PlaceableColorPicker {
                self.mediator?.signalInterest(owner, to: colorPicker, or: .ignore)
            } else {
                if let pinnedBottomBar = eventArgs.getSource() as? (any AnyBottomBar) {
                    self.mediator?.signalInterest(owner, to: pinnedBottomBar, or: .ignore)
                } else {
                    if let searchController = eventArgs.getSource() as? (any AnySearchController) {
                        self.mediator?.signalInterest(owner, to: searchController, or: .ignore)
                    } else {
                        if let carouselComponent = eventArgs.getSource() as? CarouselComponent {
                            self.mediator?.signalInterest(owner, to: carouselComponent)
                        }
                    }
                }
            }
        }
    }
    
    public func peerDidAttach(eventArgs: ZTronObservation.BroadcastArgs) {
 
    }
    
    public func notify(args: ZTronObservation.BroadcastArgs) {
        guard let args = (args as? MSAArgs) else { return }
        guard let owner = self.owner else { return }
                
        if let topbar = args.getRoot() as? (any AnyTopbarModel) {
            self.handleTopbarNotification(topbar, arg: args)
        } else {
            if let colorPicker = args.getSource() as? PlaceableColorPicker {
                self.handleColorPickerNotification(colorPicker)
            } else {
                if let pinnedBottomBar = args.getSource() as? (any AnyBottomBar) {
                    Task {
                        self.handlePinnedBottomBarNotification(pinnedBottomBar)
                    }
                } else {
                    if let searchController = args.getSource() as? (any AnySearchController) {
                        self.handleSearchControllerNotifications(searchController)
                    } else {
                        if let carousel = args.getSource() as? CarouselComponent {
                            MainActor.assumeIsolated {
                                self.currentImage = carousel.currentMediaDescriptor?.getAssetName()
                                
                                if !self.acknowledgedTopbar && carousel.lastAction == .ready {
                                    do {
                                        self.currentGalleryName = try owner.loadImagesForGallery(nil)
                                    } catch {
                                        fatalError(error.localizedDescription)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    public func willCheckout(args: ZTronObservation.BroadcastArgs) {
        if let _ = args.getSource() as? any AnyTopbarModel {
            self.acknowledgedTopbar = false
        }
    }
    
    public func getOwner() -> (any ZTronObservation.Component)? {
        return self.owner
    }
    
    public func getMediator() -> (any ZTronObservation.Mediator)? {
        return self.mediator
    }
    
    
    private func handleTopbarNotification(_ topbar: any AnyTopbarModel, arg: BroadcastArgs) {
        guard let owner = self.owner else { return }
        guard (topbar.lastAction != .subgalleriesLoaded) else { return }
        
        if topbar.lastAction == .loadSubgallery {
            if let args = ((arg as? MSAArgs)?.getPayload() as? LoadSubgalleryRequestEventMessage) {
                do {
                    owner.setCurrentDepth(topbar.getDepth())
                    try owner.loadFirstLevelGalleries(args.master)
                } catch {
                    fatalError(error.localizedDescription)
                }
            }
        } else {
            if owner.lastAction != .ready {
                let currentGallery = topbar.getSelectedItemName()
                self.currentGalleryName = currentGallery
                
                do {
                    try owner.loadImagesForGallery(currentGallery)
                } catch {
                    fatalError(error.localizedDescription)
                }
            }
        }
    }
    
    private func handleColorPickerNotification(_ colorPicker: PlaceableColorPicker) {
        guard let owner = self.owner else  { return }
        
        if let currentGallery = self.currentGalleryName {
            
            Task(priority: .userInitiated) { @MainActor in
                guard self.currentImage == colorPicker.parentImage else { return }
                
                if colorPicker.lastAction == .colorDidChange {
                    if let colorHex = colorPicker.getSelectedColor().hexString {
                        do {
                            try DBMS.transaction { dbConnection in
                                do {
                                    try DBMS.CRUD.updateOutlineColor(
                                        for: dbConnection,
                                        colorHex: colorHex,
                                        opacity: colorPicker.getSelectedColor().cgColor.alpha,
                                        image: colorPicker.parentImage,
                                        gallery: currentGallery,
                                        tool: owner.fk.getTool(),
                                        tab: owner.fk.getTab(),
                                        map: owner.fk.getMap(),
                                        game: owner.fk.getGame()
                                    )
                                    
                                    try DBMS.CRUD.updateBoundingCircleColor(
                                        for: dbConnection,
                                        colorHex: colorHex,
                                        opacity: colorPicker.getSelectedColor().cgColor.alpha,
                                        image: colorPicker.parentImage,
                                        gallery: currentGallery,
                                        tool: owner.fk.getTool(),
                                        tab: owner.fk.getTab(),
                                        map: owner.fk.getMap(),
                                        game: owner.fk.getGame()
                                    )
                                    
                                } catch {
                                    print(error.localizedDescription)
                                    return .rollback
                                }
                                
                                return .commit
                            }
                        } catch {
                            fatalError(error.localizedDescription)
                        }
                    }
                }
            }
            
        }
    }

    
    private final func handlePinnedBottomBarNotification(_ pinnedBottomBar: any AnyBottomBar) {
        guard let owner = self.owner else { return }
        guard let currentGallery = self.currentGalleryName else { return }
        
        
        Task(priority: .userInitiated) { @MainActor in
            guard let currentImage = pinnedBottomBar.currentImage else { return }
            
            do {
                if case .tappedVariantChange(let variant) = pinnedBottomBar.lastAction {
                    try owner.loadImageDescriptor(
                        imageID: variant.getSlave(),
                        in: currentGallery,
                        variantDescriptor: variant
                    )
                } else {
                    if pinnedBottomBar.lastAction == .tappedGoBack {
                        if let lastTappedVariantDescriptor = pinnedBottomBar.lastTappedVariantDescriptor {
                            try self.owner?.loadImageDescriptor(
                                imageID: lastTappedVariantDescriptor.getMaster(),
                                in: currentGallery,
                                variantDescriptor: lastTappedVariantDescriptor
                            )
                        }
                    } else {
                        try DBMS.transaction { dbConnection in
                            do {
                                if pinnedBottomBar.lastAction == .toggleOutline {
                                    try DBMS.CRUD.toggleOutlineActive(
                                        for: dbConnection,
                                        image: currentImage,
                                        gallery: currentGallery,
                                        tool: owner.fk.getTool(),
                                        tab: owner.fk.getTab(),
                                        map: owner.fk.getMap(),
                                        game: owner.fk.getGame()
                                    )
                                } else {
                                    if pinnedBottomBar.lastAction == .toggleBoundingCircle {
                                        try DBMS.CRUD.toggleBoundingCircleActive(
                                            for: dbConnection,
                                            image: currentImage,
                                            gallery: currentGallery,
                                            tool: owner.fk.getTool(),
                                            tab: owner.fk.getTab(),
                                            map: owner.fk.getMap(),
                                            game: owner.fk.getGame()
                                        )
                                    }
                                }
                            } catch {
                                print(error.localizedDescription)
                                return .rollback
                            }
                            
                            return .commit
                        }
                    }
                }
            } catch {
                fatalError(error.localizedDescription)
            }
        }
    }
    
    private final func handleSearchControllerNotifications(_ searchController: any AnySearchController) {
        guard let owner = self.owner else { return }
        
        do {
            if searchController.lastAction == .loadGalleriesGraph {
                try owner.loadGalleriesGraph()
            } else {
                if searchController.lastAction == .loadAllMasterImages {
                    try owner.loadImagesForSearch()
                }
            }
        } catch {
            fatalError(error.localizedDescription)
        }
    }
}
