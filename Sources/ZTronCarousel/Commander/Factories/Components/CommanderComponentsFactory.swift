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
        return self.makeTopbarCommon(mediator: mediator, maxDepth: 0)
    }
    
    public func makeTopbar(mediator: MSAMediator, nestingLevel: Int, maximumDepth: Int) -> UIViewController? {
        return self.makeTopbarCommon(mediator: mediator, depth: nestingLevel, maxDepth: maximumDepth)
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

    private final func makeTopbarCommon(mediator: MSAMediator, depth: Int = 0, maxDepth: Int) -> UIViewController? {
        guard maxDepth >= depth else { return nil }
        guard maxDepth > 0 else { return nil }
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
            depth: depth
        )
                
        switch depth {
            case 0:
                return maxDepth > 1 ?
                    self.makeTopGalleriesNavigationBar(mediator: mediator, model: model) :
                    self.makeSubgalleriesRouter(mediator: mediator, model: model)
                    
            case 1:
                return self.makeSubgalleriesRouter(mediator: mediator, model: model)
            
            default:
                fatalError("At this time no default style is provided for galleries with 3 or more layers of topbars, since at the time being, there is no such a gallery that has more than 2 levels. Provide your own implementation, I suggest you to write a class that implements ZTronComponentsFactory and composes CommanderComponentsFactory, forwarding calls to makeTopbar to it for depth <= 1, and provides custom implementation for depth > 1")
        }
    }
    
    private final func makeSubgalleriesRouter(mediator: MSAMediator, model: TopbarModel) -> UIViewController {
        let topbar = TopbarViewController(model: model, theme: self.theme)
        
        model.setDelegate(TopbarInteractionsManager(owner: model, mediator: mediator))
        
        return topbar
    }

    
    private final func makeTopGalleriesNavigationBar(mediator: MSAMediator, model: TopbarModel) -> UIViewController {
        let topbar = UIHostingController<TopbarView>(
            rootView: TopbarView(
                topbar: model
            )
        )
        
        if #available(iOS 16.0, *) {
            topbar.sizingOptions = [.intrinsicContentSize]
        }
        model.setDelegate(TopbarInteractionsManager(owner: model, mediator: mediator))
        return topbar
    }
}
