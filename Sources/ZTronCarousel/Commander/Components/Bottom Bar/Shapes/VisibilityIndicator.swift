import SwiftUI


public struct VisibilityIndicator: View {
    public var body: some View {
        Circle()
            .fill(.blue)
            .frame(width: 13, height: 13)
            .overlay(alignment: .center) {
                EyeShape()
                    .fill(.purple)
                    .frame(width: 8, height: 5)
            }

    }
}
