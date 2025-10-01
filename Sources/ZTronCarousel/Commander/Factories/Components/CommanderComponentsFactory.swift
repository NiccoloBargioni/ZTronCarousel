import Foundation
import SwiftUI
import ZTronObservation
import ZTronSerializable
import ZTronTheme

public final class CommanderComponentsFactory: ZTronComponentsFactory, Sendable {
    
    private let topbarTitle: String?
    private let theme: (any ZTronTheme)
    
    public init(
        topbarTitle: String? = nil,
        theme: any ZTronTheme = ZTronThemeProvider.default()
    ) {
        self.theme = theme
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
            title: title,
        )
                
        let topbar = TopbarViewController(model: model, theme: self.theme)
        
        model.setDelegate(TopbarInteractionsManager(owner: model, mediator: mediator))
        
        return topbar
    }
        
    public func makeBottomBar() -> any AnyBottomBar {
        let bottomBar = BottomBarView(frame: .zero)
        bottomBar.setTheme(self.theme)
        
        return bottomBar
    }
    
    public func makeCaptionView() -> any AnyCaptionView {
        let captionView = CaptionOverlay(frame: .zero)
        captionView.setTheme(self.theme)
        
        return captionView
    }
    
    public func makeConstraintsStrategy(owner: CarouselPageFromDB, _ includesTopbar: Bool) -> any ConstraintsStrategy {
        if includesTopbar {
            return CommanderWithTopbarConstraintsStrategy(owner: owner)
        } else {
            return DefaultZtronComponentsFactory().makeConstraintsStrategy(owner: owner, false)
        }
    }

}
