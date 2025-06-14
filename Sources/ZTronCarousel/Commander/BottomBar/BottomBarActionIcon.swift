import SwiftUI
import Combine

public struct BottomBarActionIcon<S: SwiftUI.Shape>: ActiveTogglableView {
    private let shape: S
    private let disabledColor: UIColor = UIColor(red: 123.0/255.0, green: 123.0/255.0, blue: 123.0/255.0, alpha: 1.0)
    @State private var isActive: Bool
    private let activityPublisher: PassthroughSubject<Void, Never> = .init()
    
    public init(shape: S, isInitiallyActive: Bool = false) {
        self.shape = shape
        self.isActive = isInitiallyActive
        
    }
    
    public var body: some View {
        self.shape
            .fill(
                self.isActive ? .primary : Color(self.disabledColor.cgColor)
            )
            .frame(width: 18, height: 18)
            .onReceive(self.activityPublisher) { _ in
                withAnimation {
                    self.isActive.toggle()
                }
            }
    }
    
    public func toggleActive() {
        self.activityPublisher.send()
    }
}

internal protocol ActiveTogglableView: View {
    func toggleActive() -> Void
}
