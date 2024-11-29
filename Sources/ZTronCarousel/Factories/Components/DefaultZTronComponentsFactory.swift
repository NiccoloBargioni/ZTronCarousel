import Foundation
import SwiftUI
import ZTronObservation
import ZTronSerializable

public final class DefaultZtronComponentsFactory: ZTronComponentsFactory, Sendable {
    public func makeDBLoader(with foreignKeys: SerializableGalleryForeignKeys) -> any AnyDBLoader {
        return DBCarouselLoader(with: foreignKeys)
    }
    
    public func makeTopbar(mediator: MSAMediator) -> UIViewController {
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
            title: "Select a charm"
        )
        
        let topbar = UIHostingController<TopbarView>(rootView: TopbarView(topbar: model))
        
        if #available(iOS 16.0, *) {
            topbar.sizingOptions = [.intrinsicContentSize]
        }
        
        model.setDelegate(TopbarInteractionsManager(owner: model, mediator: mediator))
        
        return topbar
    }
        
    public func makeBottomBar() -> any AnyBottomBar {
        return UICarouselPageBottomBar()
    }
    
    public func makeCaptionView() -> any AnyCaptionView {
        let captionView = CaptionView()
        
        captionView.maxNumberOfLinesCollapsed = 3
        captionView.bodyColor = UIColor.label
        Task(priority: .userInitiated) { @MainActor in
            captionView.setText(body: "Nullam dignissim quam ut enim volutpat porta posuere ut diam. Praesent efficitur sagittis sapien, ac mollis tellus bibendum sit amet. Sed pharetra, lacus a dictum scelerisque, est dolor tincidunt turpis, vel ornare arcu eros ac ligula. Ut feugiat sagittis ipsum, et vestibulum nulla vehicula ut. Nulla purus leo, feugiat luctus nulla eget, pharetra tempus est.")
        }
        
        return captionView
    }
}
