import SwiftUI
import Combine

public struct BottomBarActionIcon<S: SwiftUI.Shape>: SwiftUI.View, ActiveTogglableView {
    private let shape: S
    private let disabledColor: UIColor = UIColor(red: 123.0/255.0, green: 123.0/255.0, blue: 123.0/255.0, alpha: 1.0)
    
    @State private var isActive: Bool
    
    // MARK: - TO SUPPORT MUTING UNAVAILABLE CONTENTS
    /// Distinct from `isActive`: this reflects whether the underlying content *exists* on the
    /// current image, not whether it's currently toggled on. When `false` it overrides whatever
    /// `isActive` would otherwise render, since an active/inactive distinction is moot for a
    /// content that isn't there to toggle.
    @State private var isEnabled: Bool = true
    @State private var mutedColor: Color = .gray
    
    private let activityPublisher: PassthroughSubject<Void, Never> = .init()
    private let setActivityPublisher: PassthroughSubject<Bool, Never> = .init()
    private let setEnabledPublisher: PassthroughSubject<(Bool, UIColor), Never> = .init()
    
    
    public init(shape: S, isInitiallyActive: Bool = false) {
        self.shape = shape
        self.isActive = isInitiallyActive
        
    }
    
    public var body: some View {
        self.shape
            .fill(
                !self.isEnabled
                    ? self.mutedColor
                    : (self.isActive ? .primary : Color(self.disabledColor.cgColor))
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
            .onReceive(self.setEnabledPublisher.receive(on: RunLoop.main)) { isEnabled, mutedColor in
                self.isEnabled = isEnabled
                self.mutedColor = Color(mutedColor)
            }
    }
    
    @MainActor public func toggleActive() {
        self.activityPublisher.send()
    }
    
    @MainActor public func setActive(_ isActive: Bool) {
        self.setActivityPublisher.send(isActive)
    }
    
    @MainActor public func setEnabled(_ isEnabled: Bool, mutedColor: UIColor) {
        self.setEnabledPublisher.send((isEnabled, mutedColor))
    }
    
}

public protocol ActiveTogglableView: Any {
    @MainActor func toggleActive() -> Void
    @MainActor func setActive(_ isActive: Bool) -> Void
    
    // MARK: - TO SUPPORT MUTING UNAVAILABLE CONTENTS
    @MainActor func setEnabled(_ isEnabled: Bool, mutedColor: UIColor) -> Void
}

public extension ActiveTogglableView {
    /// Default no-op, so any existing conformer outside this feature's scope (variant and
    /// go-back buttons, which are never muted) keeps compiling unchanged.
    @MainActor func setEnabled(_ isEnabled: Bool, mutedColor: UIColor) -> Void {
        
    }
}
