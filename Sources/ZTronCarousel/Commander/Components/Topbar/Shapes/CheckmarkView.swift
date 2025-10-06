import SwiftUI

struct CheckmarkView: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        path.move(to: CGPoint(x: (0.39792 - 0.16042)/(0.83958 - 0.16042)*width, y: (-0.25 + 0.75104)/(-0.25 + 0.75104)*height))
        path.addLine(to: CGPoint(x: (0.16042 - 0.16042)/(0.83958 - 0.16042)*width, y: (-0.4875 + 0.75104)/(-0.25 + 0.75104)*height))
        path.addLine(to: CGPoint(x: (0.21979 - 0.16042)/(0.83958 - 0.16042)*width, y: (-0.54688 + 0.75104)/(-0.25 + 0.75104)*height))
        path.addLine(to: CGPoint(x: (0.39792 - 0.16042)/(0.83958 - 0.16042)*width, y: (-0.36875 + 0.75104)/(-0.25 + 0.75104)*height))
        path.addLine(to: CGPoint(x: (0.78021 - 0.16042)/(0.83958 - 0.16042)*width, y: (-0.75104 + 0.75104)/(-0.25 + 0.75104)*height))
        path.addLine(to: CGPoint(x: (0.83958 - 0.16042)/(0.83958 - 0.16042)*width, y: (-0.69167 + 0.75104)/(-0.25 + 0.75104)*height))
        path.addLine(to: CGPoint(x: (0.39792 - 0.16042)/(0.83958 - 0.16042)*width, y: (-0.25 + 0.75104)/(-0.25 + 0.75104)*height))
        path.closeSubpath()
        return path
    }
}
