import SwiftUI
import Combine

public struct BottomBarActionIcon<S: SwiftUI.Shape>: SwiftUI.View, ActiveTogglableView {
    private let shape: S
    private let disabledColor: UIColor = UIColor(red: 123.0/255.0, green: 123.0/255.0, blue: 123.0/255.0, alpha: 1.0)
    
    @State private var isActive: Bool
    
    private let activityPublisher: PassthroughSubject<Void, Never> = .init()
    private let setActivityPublisher: PassthroughSubject<Bool, Never> = .init()
    
    
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
            .onReceive(self.setActivityPublisher.receive(on: RunLoop.main)) { isActive in
                self.isActive = isActive
            }
    }
    
    @MainActor public func toggleActive() {
        self.activityPublisher.send()
    }
    
    @MainActor public func setActive(_ isActive: Bool) {
        self.setActivityPublisher.send(isActive)
    }
    
}

public protocol ActiveTogglableView: Any {
    @MainActor func toggleActive() -> Void
    @MainActor func setActive(_ isActive: Bool) -> Void
}
