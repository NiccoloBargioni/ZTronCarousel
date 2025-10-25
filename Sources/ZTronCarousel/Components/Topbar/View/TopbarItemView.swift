import SwiftUI
import ZTronTheme

public struct TopbarItemView<T: ZTronTheme>: View {
    private var tool: any TopbarComponent
    private let isActive: Bool
    
    private var glowColor: SwiftUI.Color
    private var shouldHighlightText: Bool = true
    private var theme: T
    
    public init(
        tool: any TopbarComponent,
        isActive: Bool,
        theme: T = ZTronThemeProvider.default().erasedToAnyTheme()
    ) {
        self.tool = tool
        self.isActive = isActive
        self.theme = theme
        
        self.glowColor = Color(self.theme, value: \.sunsetSky)
    }
    
    public var body: some View {
        VStack {
            TopbarItemShopWindow(icon: tool.getIcon(), isActive: isActive)
                .glowColor(self.glowColor)
            
            Text(tool.getName().fromLocalized())
                .font(
                    theme: self.theme,
                    font: \.caption2, weight: self.shouldHighlightText && isActive ? .bold : .regular
                )
                .lineLimit(2)
               .foregroundColor(
                    self.shouldHighlightText && self.isActive
                    ? self.glowColor : Color(self.theme, value: \.label)
                )
                .frame(minWidth: TopbarItemShopWindow.radius, idealWidth: TopbarItemShopWindow.radius + 10, maxWidth: TopbarItemShopWindow.radius * 3)
        }
        .lineLimit(nil)
    }
}

public extension TopbarItemView {
    func glowColor(_ color: SwiftUI.Color) -> Self {
        var copy = self
        copy.glowColor = color
        return copy
    }
    
    func highlightText(_ shouldHighlightText: Bool = true) -> Self {
        var copy = self
        copy.shouldHighlightText = shouldHighlightText
        return copy
    }
}
