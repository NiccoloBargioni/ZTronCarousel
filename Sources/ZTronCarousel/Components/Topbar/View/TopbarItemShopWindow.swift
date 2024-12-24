import SwiftUI

public struct TopbarItemShopWindow: View {
    private let isActive: Bool
    private let icon: String
    public static let radius: CGFloat = 55.0
    private var glowColor: SwiftUI.Color = .cyan
    
    
    public init(icon: String, isActive: Bool) {
        self.isActive = isActive
        self.icon = icon
    }
    
    public var body: some View {
        ZStack {
          Circle()
            .strokeBorder(
              isActive
                  ? self.glowColor
              : Color(UIColor.label)
                  .opacity(0.3)
            )
            .frame(width: Self.radius, height: Self.radius)
            .shadow(
              color:
                isActive
                  ? self.glowColor
                : .clear,
              radius: 1, x: 0, y: 0)

          Circle()
            .fill(
              .clear
            )
            .frame(width: Self.radius, height: Self.radius)
            Image(self.icon)
            .resizable()
            .frame(width: Self.radius * 0.65, height: Self.radius * 0.65)
            .clipShape(Circle())
        }
    }
}

public extension TopbarItemShopWindow {
    func glowColor(_ color: SwiftUI.Color) -> Self {
        var copy = self
        copy.glowColor = color
        return copy
    }
}
