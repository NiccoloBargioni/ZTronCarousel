import UIKit
import SwiftUI
import ZTronTheme

public final class TopbarRouterView: UIView {
    
    private let topbarModel: AnyTopbarViewModel
    private var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.showsHorizontalScrollIndicator = false
        sv.showsVerticalScrollIndicator = false
        
        return sv
    }()
        
    private var progressIndicator: UIView!
    private var progressIndicatorTotal: UIView!
    private let theme: (any ZTronTheme)

    private var progressIndicatorRight: NSLayoutConstraint!
    private let diameter: CGFloat
    
    private var makeViewForImage: (any TopbarComponent, UIAction, CGFloat) -> any AnyTopbarComponentView
    private var makeViewForLogo: (any TopbarComponent, UIAction, CGFloat) -> any AnyTopbarComponentView
    
    public init(
        model: AnyTopbarViewModel,
        diameter: CGFloat = 30.0,
        theme: any ZTronTheme = ZTronThemeProvider.default(),
        makeViewForImage: @escaping (any TopbarComponent, UIAction, CGFloat) -> any AnyTopbarComponentView = { component, action, diameter in
            
            return TopbarComponentView(
                component: component,
                action: action,
                diameter: diameter,
            )
        },
        makeViewForLogo: @escaping (any TopbarComponent, UIAction, CGFloat) -> any AnyTopbarComponentView = { component, action, diameter in
            
            return AnonymousTopbarComponentView(
                component: component,
                action: action,
                diameter: diameter,
            )
        }
    ) {
        self.topbarModel = model
        self.diameter = diameter
        self.theme = theme
        self.makeViewForImage = makeViewForImage
        self.makeViewForLogo = makeViewForLogo
        super.init(frame: .zero)
        
        self.backgroundColor = UIColor.clear
        
        self.scrollView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(self.scrollView)
        
        // MARK: - ROUTER
        NSLayoutConstraint.activate([
            self.scrollView.widthAnchor.constraint(greaterThanOrEqualTo: self.safeAreaLayoutGuide.widthAnchor, constant: -10),
            self.scrollView.leftAnchor.constraint(equalTo: self.safeAreaLayoutGuide.leftAnchor),
            self.scrollView.bottomAnchor.constraint(equalTo: self.safeAreaLayoutGuide.bottomAnchor),
            self.scrollView.topAnchor.constraint(equalTo: self.safeAreaLayoutGuide.topAnchor),
            self.scrollView.frameLayoutGuide.heightAnchor.constraint(equalTo: self.scrollView.contentLayoutGuide.heightAnchor),
            
            self.scrollView.contentLayoutGuide.leftAnchor.constraint(lessThanOrEqualTo: self.safeAreaLayoutGuide.leftAnchor),
            self.scrollView.contentLayoutGuide.rightAnchor.constraint(greaterThanOrEqualTo: self.safeAreaLayoutGuide.rightAnchor),
        ])

        
        for i in 0..<self.topbarModel.count() {
            self.makeTopbarItemForModel(ofIndex: i)
        }
        
        
        self.scrollView.backgroundColor = .clear
        
        for i in 1..<self.scrollView.subviews.count {
            guard let viewForLogoPrev = (self.scrollView.subviews[i-1] as? any AnyTopbarComponentView)?.viewForLogo() else { continue }
            guard let viewForLogoCurrent = (self.scrollView.subviews[i] as? any AnyTopbarComponentView)?.viewForLogo() else { continue }
 
            NSLayoutConstraint.activate([
                viewForLogoCurrent.leftAnchor.constraint(equalTo: viewForLogoPrev.safeAreaLayoutGuide.centerXAnchor, constant: 60 + self.diameter / 2.0),
            ])
        }
        
        NSLayoutConstraint.activate([
            self.scrollView.contentLayoutGuide.leftAnchor.constraint(equalTo: self.scrollView.subviews.first!.leftAnchor, constant: -5),
            self.scrollView.contentLayoutGuide.rightAnchor.constraint(greaterThanOrEqualTo: self.scrollView.subviews.last!.rightAnchor)
        ])

        
        // MARK: - PROGRESS MARKERS
        let progressIndicatorTotal: UIView = .init()
        progressIndicatorTotal.backgroundColor = UIColor.fromTheme(self.theme.colorSet, color: \.disabled).withAlphaComponent(0.2)
        
        self.scrollView.addSubview(progressIndicatorTotal)
        progressIndicatorTotal.translatesAutoresizingMaskIntoConstraints = false
        
        if let viewForLogoFirst = (self.scrollView.subviews.first as? any AnyTopbarComponentView)?.viewForLogo() {
            if let viewForLogosLast = (self.scrollView.subviews[self.scrollView.subviews.count - 2] as? any AnyTopbarComponentView)?.viewForLogo() {
                NSLayoutConstraint.activate([
                    progressIndicatorTotal.leftAnchor.constraint(equalTo: viewForLogoFirst.safeAreaLayoutGuide.centerXAnchor),
                    progressIndicatorTotal.centerYAnchor.constraint(equalTo: viewForLogoFirst.safeAreaLayoutGuide.centerYAnchor),
                    progressIndicatorTotal.rightAnchor.constraint(equalTo: viewForLogosLast.safeAreaLayoutGuide.centerXAnchor),
                    progressIndicatorTotal.heightAnchor.constraint(equalToConstant: 1)
                ])
            }
        }
        
        self.progressIndicatorTotal = progressIndicatorTotal
        
        let progressIndicatorCurrent: UIView = .init()
        progressIndicatorCurrent.backgroundColor = UIColor.fromTheme(self.theme.colorSet, color: \.brand)

        
        self.scrollView.addSubview(progressIndicatorCurrent)
        progressIndicatorCurrent.translatesAutoresizingMaskIntoConstraints = false
        
        if let viewForLogoFirst = (self.scrollView.subviews.first as? any AnyTopbarComponentView)?.viewForLogo() {
            NSLayoutConstraint.activate([
                progressIndicatorCurrent.leftAnchor.constraint(equalTo: viewForLogoFirst.safeAreaLayoutGuide.centerXAnchor),
                progressIndicatorCurrent.centerYAnchor.constraint(equalTo: viewForLogoFirst.safeAreaLayoutGuide.centerYAnchor),
                progressIndicatorCurrent.heightAnchor.constraint(equalToConstant: 1)
            ])
        }
        
        progressIndicatorCurrent.layer.zPosition = 1.0
        
        self.progressIndicator = progressIndicatorCurrent
        
        if let viewForLogoCurrent = (self.scrollView.subviews[self.topbarModel.getSelectedItem()] as? any AnyTopbarComponentView)?.viewForLogo()  {
            self.progressIndicatorRight = progressIndicatorCurrent.rightAnchor.constraint(equalTo: viewForLogoCurrent.safeAreaLayoutGuide.centerXAnchor)
            
            self.progressIndicatorRight.isActive = true
        }
        
        self.progressIndicatorTotal.accessibilityIdentifier = "background completion indicator"
        self.progressIndicator.accessibilityIdentifier = "foreground completion indicator"

        self.topbarModel.onItemsReplaced(self.onItemsChanged(_:))
    }
    
    required public init?(coder: NSCoder) {
        fatalError()
    }
    
    
    public final func updateCurrentSelection(_ index: Int) {
        assert(index >= 0 && index < self.scrollView.subviews.count)
        
        self.topbarModel.setSelectedItem(item: index)
        
        let componentSubviews = self.allComponentSubviews()
        let currentItem = componentSubviews[index]
        
        currentItem.makeActive()
        
        for i in 0..<index {
            self.scrollView.layoutIfNeeded()
            componentSubviews[i].makeVisited()
        }
        
        componentSubviews[index].makeActive()
        
        for i in index+1..<componentSubviews.count {
            self.scrollView.layoutIfNeeded()
            componentSubviews[i].makeUnvisited()
        }
        
        self.scrollView.layoutIfNeeded()

        self.progressIndicatorRight.isActive = false
        self.progressIndicatorRight = self.progressIndicator.rightAnchor.constraint(equalTo: currentItem.viewForLogo()!.centerXAnchor)
        self.progressIndicatorRight.isActive = true

        UIView.animate(withDuration: 0.25) { @MainActor in
            self.scrollView.layoutIfNeeded()
        }
        
        self.scrollView.centerScrollContent(self.nthComponentView(self.topbarModel.getSelectedItem())!)
    }
    
    
    public final func viewDidTransition(to size: CGSize) {
        self.scrollView.centerScrollContent(self.scrollView.subviews[self.topbarModel.getSelectedItem()])
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
    }
    
    
    /// ```
    /// ScrollView
    /// |--------|
    /// |--------some TopbarComponentContainer (any AnyTopbarComponentView)
    /// |--------some TopbarComponentContainer (any AnyTopbarComponentView)
    /// |--------some TopbarComponentContainer (any AnyTopbarComponentView)
    /// |--------                       [....]
    /// |--------some TopbarComponentContainer (any AnyTopbarComponentView)
    /// |--------Visibility Indicator Total (disabled)
    /// |--------Visibility Indicator Completion (brand)
    /// |--------Scroll Thumb
    /// ```
    ///
    /// - Note: At this point it is assumed that `topbarModel.items == items`
    @MainActor internal final func onItemsChanged(_ items: [any TopbarComponent]) {
        var itemSubviews = self.scrollView.subviews.compactMap { subview in
            return subview as? any AnyTopbarComponentView
        }
            
        #if DEBUG
        items.enumerated().forEach { i, item in
            assert(item.getName().fromLocalized() == self.topbarModel.get(i).getName().fromLocalized())
            assert(item.getIcon().fromLocalized() == self.topbarModel.get(i).getIcon().fromLocalized())
        }
        #endif
        
        if itemSubviews.count != items.count {
            self.scrollView.constraints.compactMap { constraint in
                if (constraint.firstItem as? UILayoutGuide) == scrollView.contentLayoutGuide ||
                    (constraint.secondItem as? UILayoutGuide) == scrollView.contentLayoutGuide {
                    if constraint.firstAnchor == scrollView.contentLayoutGuide.rightAnchor ||
                        constraint.secondAnchor == scrollView.contentLayoutGuide.rightAnchor {
                        return constraint
                    } else {
                        return nil
                    }
                } else {
                    return nil
                }
            }.forEach {
                itemSubviews.last?.removeConstraint($0)
            }
            
            self.progressIndicatorTotal.removeAllRightAnchorConstraints()
        }
        
        if itemSubviews.count >= items.count {
            for i in 0..<items.count {
                if UIImage.exists(items[i].getIcon()) && (itemSubviews[i] as? TopbarComponentView) != nil ||
                    !UIImage.exists(items[i].getIcon()) && (itemSubviews[i] as? AnonymousTopbarComponentView) != nil {
                    itemSubviews[i].replaceModel(with: items[i])
                } else {
                    replaceNthComponentSubview(i, itemSubviews: &itemSubviews)
                }
            }
            
            if itemSubviews.count > items.count {
                for i in items.count..<itemSubviews.count {
                    itemSubviews[i].removeFromSuperview()
                    self.layoutIfNeeded()
                }
                
                if self.topbarModel.getSelectedItem() > items.count {
                    self.topbarModel.setSelectedItem(item: items.count - 1)
                }
            }
        } else {
            for i in 0..<itemSubviews.count {
                if UIImage.exists(items[i].getIcon()) && (itemSubviews[i] as? TopbarComponentView) != nil ||
                    !UIImage.exists(items[i].getIcon()) && (itemSubviews[i] as? AnonymousTopbarComponentView) != nil {
                    itemSubviews[i].replaceModel(with: items[i])
                } else {
                    replaceNthComponentSubview(i, itemSubviews: &itemSubviews)
                }
            }
            
            for i in itemSubviews.count..<items.count {
                self.makeTopbarItemForModel(ofIndex: i)
            }
            
            let updatedItemSubviews = self.scrollView.subviews.compactMap { subview in
                return subview as? any AnyTopbarComponentView
            }
        
            
            for i in itemSubviews.count..<items.count {
                NSLayoutConstraint.activate([
                    updatedItemSubviews[i].leftAnchor.constraint(equalTo: updatedItemSubviews[i-1].safeAreaLayoutGuide.centerXAnchor, constant: 60 + self.diameter / 2.0),
                ])
                
                self.layoutIfNeeded()
            }
        }
        
        if itemSubviews.count != items.count {
            if let lastTopbarItem = self.lastComponentView() {
                NSLayoutConstraint.activate([
                    self.scrollView.contentLayoutGuide.rightAnchor.constraint(greaterThanOrEqualTo: lastTopbarItem.rightAnchor),
                    self.progressIndicatorTotal.rightAnchor.constraint(equalTo: lastTopbarItem.safeAreaLayoutGuide.centerXAnchor)
                ])
                
                self.layoutIfNeeded()
            }
        }
        
        assert(self.allComponentSubviews().count == items.count)
        assert(self.allComponentSubviews().count == self.topbarModel.count())
        
        self.updateCurrentSelection(self.topbarModel.getSelectedItem())
    }
    
    private final func firstComponentView() -> (any AnyTopbarComponentView)? {
        return self.scrollView.subviews.first { subview in
            return subview as? any AnyTopbarComponentView != nil
        } as? any AnyTopbarComponentView
    }
    
    private final func firstComponentViewIndex() -> Int? {
        return self.scrollView.subviews.firstIndex { subview in
            return subview as? any AnyTopbarComponentView != nil
        }
    }
    
    private final func lastComponentView() -> (any AnyTopbarComponentView)? {
        return self.scrollView.subviews.last { subview in
            return subview as? any AnyTopbarComponentView != nil
        }  as? any AnyTopbarComponentView
    }
    
    private final func lastComponentViewIndex() -> Int? {
        return self.scrollView.subviews.lastIndex { subview in
            return subview as? any AnyTopbarComponentView != nil
        }
    }
    
    private final func nthComponentView(_ n: Int) -> (any AnyTopbarComponentView)? {
        return self.scrollView.subviews.compactMap { subview in
            return subview as? any AnyTopbarComponentView != nil ? subview : nil
        }[n]  as? any AnyTopbarComponentView
    }
    
    private final func allComponentSubviews() -> [(any AnyTopbarComponentView)] {
        return self.scrollView.subviews.compactMap { subview -> (any AnyTopbarComponentView)? in
            if let subview = subview as? any AnyTopbarComponentView {
                return subview
            } else {
                return nil
            }
        }
    }
    
    @discardableResult private final func makeTopbarItemForModel(ofIndex i: Int, insertAtIndex: Int? = nil) -> any AnyTopbarComponentView {
        let topbarComponent = self.topbarModel.get(i)
        
        let action: UIAction = UIAction(title: "Skip to topbar item \(i)") { _ in
            self.updateCurrentSelection(i)
            self.topbarModel.setSelectedItem(item: i)
        }
        
        let topbarComponentContainer: any AnyTopbarComponentView = UIImage.exists(topbarComponent.getIcon()) ?
            self.makeViewForImage(topbarComponent, action, self.diameter):
        self.makeViewForLogo(topbarComponent, action, self.diameter)
        
        
        topbarComponentContainer.accessibilityIdentifier = "\(self.topbarModel.get(i).getName())"
        
        if let atIndex = insertAtIndex {
            self.scrollView.insertSubview(topbarComponentContainer, at: atIndex)
            assert(topbarComponentContainer.superview == self.scrollView)
        } else {
            self.scrollView.addSubview(topbarComponentContainer)
        }
        
        topbarComponentContainer.translatesAutoresizingMaskIntoConstraints = false
        
        if self.topbarModel.getSelectedItem() == i {
            topbarComponentContainer.makeActive()
            
            let allComponents = self.allComponentSubviews()
            for j in 0..<i {
                allComponents[j].makeVisited()
            }
            
            for j in (i + 1)..<allComponents.count {
                allComponents[j].makeUnvisited()
            }
        }
        
        NSLayoutConstraint.activate([
            topbarComponentContainer.topAnchor.constraint(equalTo: self.scrollView.safeAreaLayoutGuide.topAnchor),
            self.scrollView.contentLayoutGuide.heightAnchor.constraint(greaterThanOrEqualTo: topbarComponentContainer.heightAnchor),
        ])
        
        
        topbarComponentContainer.setContentHuggingPriority(.required, for: .vertical)
        topbarComponentContainer.setContentHuggingPriority(.required, for: .horizontal)
        
        return topbarComponentContainer
    }
    
    @discardableResult private final func replaceNthComponentSubview(_ n: Int, itemSubviews: inout [any AnyTopbarComponentView]) -> (any AnyTopbarComponentView)? {
        assert(n >= 0 && n < self.scrollView.subviews.count)
        assert(n >= 0 && n < self.topbarModel.count())
        
        if let indexOfItem = self.scrollView.subviews.firstIndex(of: itemSubviews[n]) {
            itemSubviews[n].removeFromSuperview()
            self.scrollView.layoutIfNeeded()
            
            let previousSubview = n > 0 ? itemSubviews[n - 1] : nil
            let nextSubview = n < itemSubviews.count - 1 ? itemSubviews[n + 1] : nil
            
            let newViewForCurrent = self.makeTopbarItemForModel(ofIndex: n, insertAtIndex: indexOfItem)
            itemSubviews[n] = newViewForCurrent
            
            
            if let previousSubview = previousSubview {
                self.scrollView.layoutIfNeeded()

                NSLayoutConstraint.activate([
                    newViewForCurrent.leftAnchor.constraint(equalTo: previousSubview.safeAreaLayoutGuide.centerXAnchor, constant: 60 + self.diameter / 2.0),
                ])
                
                self.scrollView.layoutIfNeeded()
            }
            
            if let nextSubview = nextSubview {
                self.scrollView.layoutIfNeeded()
                
                NSLayoutConstraint.activate([
                    nextSubview.leftAnchor.constraint(equalTo: newViewForCurrent.safeAreaLayoutGuide.centerXAnchor, constant: 60 + self.diameter / 2.0),
                ])
            }
            
            if n == 0 {
                NSLayoutConstraint.activate([
                    self.scrollView.contentLayoutGuide.leftAnchor.constraint(equalTo: newViewForCurrent.leftAnchor, constant: -5),
                    self.progressIndicatorTotal.leftAnchor.constraint(equalTo: newViewForCurrent.safeAreaLayoutGuide.centerXAnchor),
                ])
                
                if let logoView = newViewForCurrent.viewForLogo() {
                    NSLayoutConstraint.activate([
                        self.progressIndicatorTotal.centerYAnchor.constraint(equalTo: logoView.safeAreaLayoutGuide.centerYAnchor),
                        self.progressIndicator.leftAnchor.constraint(equalTo: newViewForCurrent.safeAreaLayoutGuide.centerXAnchor),
                        self.progressIndicator.centerYAnchor.constraint(equalTo: logoView.safeAreaLayoutGuide.centerYAnchor),
                    ])
                }
            } else {
                if n == itemSubviews.count - 1 {
                    NSLayoutConstraint.activate([
                        self.scrollView.contentLayoutGuide.rightAnchor.constraint(greaterThanOrEqualTo: newViewForCurrent.rightAnchor),
                        self.progressIndicatorTotal.rightAnchor.constraint(equalTo: newViewForCurrent.safeAreaLayoutGuide.centerXAnchor)
                    ])
                    
                    self.scrollView.layoutIfNeeded()
                }
            }
            
            return newViewForCurrent
        } else {
            return nil
        }
    }
    
    internal final func collapse() -> Void {
        guard !self.isHidden else { return }
        
        self.scrollView.subviews.forEach { subview in
            UIView.animate(withDuration: 0.25) {
                subview.layer.opacity = 0
            } completion: { _ in
                subview.isHidden = true
            }
        }
        
        UIView.animate(withDuration: 0.25) {
            self.scrollView.layer.opacity = 0
        } completion: { _ in
            self.scrollView.isHidden = true
        }
    }
    
    internal final func expand() -> Void {
        guard self.isHidden else { return }
        
        self.scrollView.isHidden = false
        UIView.animate(withDuration: 0.25) {
            self.scrollView.layer.opacity = 1
        }

        self.scrollView.subviews.forEach { subview in
            subview.layer.isHidden = false

            UIView.animate(withDuration: 0.25) {
                subview.layer.opacity = 1
            }
        }
    }
}
