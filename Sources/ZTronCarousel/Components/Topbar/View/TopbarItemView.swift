import SwiftUI

public struct TopbarItemView: View {
    private var tool: any TopbarComponent
    private let isActive: Bool
    
    private var glowColor: SwiftUI.Color = .cyan

    public init(tool: any TopbarComponent, isActive: Bool) {
        self.tool = tool
        self.isActive = isActive
    }

    public var body: some View {
    VStack {
        TopbarItemShopWindow(icon: tool.getIcon(), isActive: isActive)
            .glowColor(self.glowColor)
      Text(
        LocalizedStringKey(
          String(
            tool.getName()
          )
        )
      )
      .fontWeight(
        isActive ? .bold : .regular
      )
      .foregroundColor(
        isActive
            ? self.glowColor : Color(UIColor.label)
      )
      .font(.caption2)
      .frame(minWidth: TopbarItemShopWindow.radius, idealWidth: TopbarItemShopWindow.radius + 10, maxWidth: TopbarItemShopWindow.radius * 3)
    }
    .lineLimit(nil)
    }
}

#Preview {
    TopbarItemView(tool: TopbarItem(icon: "arrowHeadIcon", name: "Arrow head"), isActive: true)
}

public extension TopbarItemView {
    func glowColor(_ color: SwiftUI.Color) -> Self {
        var copy = self
        copy.glowColor = color
        return copy
    }
}
