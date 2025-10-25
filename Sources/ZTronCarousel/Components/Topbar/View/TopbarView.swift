import SwiftUI
import ZTronTheme
import Combine

public struct TopbarView<M, I, T>: View where I: View, M: AnyTopbarModel, T: ZTronTheme {
    @ObservedObject private var topbar: M
    private let itemBuilder: (_: any TopbarComponent, _: Bool) -> I
    private let theme: T
    
    private let sendVisibilityMessage: PassthroughSubject<Bool, Never> = .init()
    
    @State private var shouldShowTopbar: Bool = true
    @Namespace private var animations
    
    public init(
        topbar: M,
        themeProvider: T = ZTronThemeProvider.default().erasedToAnyTheme(),
        @ViewBuilder item: @escaping (_: any TopbarComponent, _: Bool) -> I = { component, active in
            return TopbarItemView(
                tool: component,
                isActive: active,
                theme: ZTronThemeProvider.default().erasedToAnyTheme()
            )
        }
    ) {
        self._topbar = ObservedObject(wrappedValue: topbar)
        self.itemBuilder = item
        self.theme = themeProvider
    }
    
    public var body: some View {
        //MARK: - Topbar
        Group {
            if self.shouldShowTopbar {
                self.Topbar()
                    .matchedGeometryEffect(id: "topbar", in: self.animations)
            } else {
                self.Topbar()
                    .matchedGeometryEffect(id: "topbar", in: self.animations).hidden()
            }
        }
        .onAppear {
            self.topbar.onHideRequest {
                self.sendVisibilityMessage.send(false)
            }
            
            self.topbar.onShowRequest {
                self.sendVisibilityMessage.send(true)
            }
        }
    }
    
    @ViewBuilder private func Topbar() -> some View {
        VStack(alignment: .leading, spacing: 0) {
           /*
           //MARK: Topbar title
           HStack {
               Text(self.topbar.title.fromLocalized().capitalized)
                   .font(theme: self.theme, font: \.headline, weight: .semibold)
                   .padding(.horizontal, 15)
                   .padding(.vertical, 5)
                   .foregroundColor(
                       Color(self.theme, value: \.label).opacity(0.7)
                   )
               Spacer()
           }
           
           Divider()
               .padding(0)
           */
            
           //MARK: Topbar item selection view
           ScrollView(.horizontal, showsIndicators: false) {
               ScrollViewReader { scroll in
                   HStack(alignment: .top, spacing: 25) {
                       ForEach(0..<topbar.count(), id:\.self) { i in
                           Button(action: {
                               withAnimation(.easeOut(duration: 0.5)) {
                                   topbar.setSelectedItem(item: i)
                               }
                           }) {
                               self.itemBuilder(
                                   topbar.get(i),
                                   topbar.getSelectedItem() == i
                               )
                           }
                           .id(i)
                       }
                       
                   }
                   .frame(maxHeight: 100)
                   .onChange(of: self.topbar.getSelectedItem()) { newSelectedItemIndex in
                       withAnimation(.linear(duration: 0.25)) {
                           scroll.scrollTo(newSelectedItemIndex, anchor: .center)
                       }
                   }
               }
           }
           .padding()
            
       }
       .frame(maxWidth: .infinity)
       .gradientAppBackground()
       .redacted(reason: self.topbar.redacted ? .placeholder : [])
       .onReceive(self.sendVisibilityMessage.receive(on: RunLoop.main)) { show in
           self.shouldShowTopbar = show
       }
    }
}

#Preview {
    TopbarView(
        topbar: TopbarModel(
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
            title: "Select a charm",
        ),
        themeProvider: ZTronThemeProvider.default().erasedToAnyTheme()
    )
}
