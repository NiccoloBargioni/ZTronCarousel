import SwiftUI

internal struct TopbarItemView: View {
    static private let radius: CGFloat = 55.0
    private var tool: any TopbarComponent
    private let isActive: Bool

    init(tool: any TopbarComponent, isActive: Bool) {
        self.tool = tool
        self.isActive = isActive
    }

    var body: some View {
    VStack {
      ZStack {
        Circle()
          .strokeBorder(
            isActive
              ? .cyan
            : Color(UIColor.label)
                .opacity(0.3)
          )
          .frame(width: Self.radius, height: Self.radius)
          .shadow(
            color:
              isActive
              ? .cyan
              : .clear,
            radius: 1, x: 0, y: 0)

        Circle()
          .fill(
            .clear
          )
          .frame(width: Self.radius, height: Self.radius)
        Image(tool.getIcon())
          .resizable()
          .frame(width: Self.radius * 0.65, height: Self.radius * 0.65)
          .clipShape(Circle())
      }
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
          ? .cyan : Color(UIColor.label)
      )
      .font(.caption2)
      .frame(minWidth: Self.radius, idealWidth: Self.radius + 10, maxWidth: Self.radius * 3)

    }
    .lineLimit(nil)
    }
}

#Preview {
    TopbarItemView(tool: TopbarItem(icon: "arrowHeadIcon", name: "Arrow head"), isActive: true)
}
