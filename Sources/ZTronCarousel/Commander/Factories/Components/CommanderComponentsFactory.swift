import Foundation
import SwiftUI
import ZTronObservation
import ZTronSerializable

public final class CommanderComponentsFactory: ZTronComponentsFactory, Sendable {
    
    private let topbarTitle: String?
    
    public init(
        topbarTitle: String? = nil
    ) {
        self.topbarTitle = topbarTitle
    }

    public func makeViewModel() -> any AnyViewModel {
        return CarouselFromDBViewModel()
    }
    
    public func makeSearchController() -> (any AnySearchController)? {
        return ZTronSearchController(fuse: .init(threshold: 0.25))
    }
    
    public func makeDBLoader(with foreignKeys: SerializableGalleryForeignKeys) -> any AnyDBLoader {
        return DBCarouselLoader(with: foreignKeys)
    }
    
    public func makeTopbar(mediator: MSAMediator) -> UIViewController? {
        guard let title = self.topbarTitle else { return nil }
        
        let model = TopbarModel(
            items: [
                .init(icon: "arrowHeadIcon", name: "Punta di freccia"),
                .init(icon: "billiardBall8Icon", name: "Pallina biliardo"),
                .init(icon: "binocularIcon", name: "Binocolo"),
                .init(icon: "bootsIcon", name: "Stivali"),
                .init(icon: "fishIcon", name: "Pesce"),
                .init(icon: "frogIcon", name: "Rana"),
                .init(icon: "maskIcon", name: "Maschera"),
                .init(icon: "pacifierIcon", name: "Ciuccio"),
                .init(icon: "ringIcon", name: "Anello"),
                .init(icon: "shovelIcon", name: "Pala"),
            ],
            title: title
        )
        
        let topbar = TopbarViewController(model: model)
        
        model.setDelegate(TopbarInteractionsManager(owner: model, mediator: mediator))
        
        return topbar
    }
        
    public func makeBottomBar() -> any AnyBottomBar {
        return BottomBarView(frame: .zero)
    }
    
    public func makeCaptionView() -> any AnyCaptionView {
        return CaptionOverlay(frame: .zero)
    }
    
    public func makeConstraintsStrategy(owner: CarouselPageFromDB, _ includesTopbar: Bool) -> any ConstraintsStrategy {
        if includesTopbar {
            return CommanderWithTopbarConstraintsStrategy(owner: owner)
        } else {
            return DefaultZtronComponentsFactory().makeConstraintsStrategy(owner: owner, false)
        }
    }

}
