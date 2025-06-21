import UIKit
import SwiftUI

public final class TopbarRouterView: UIView {
    
    private let topbarModel: TopbarModel
    
    private let disabledColor: UIColor = UIColor(red: 123.0/255.0, green: 123.0/255.0, blue: 123.0/255.0, alpha: 1.0)
    
    private var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.showsHorizontalScrollIndicator = false
        
        return sv
    }()
    
    private var visibilityIndicator: UIHostingController<VisibilityIndicator> = .init(rootView: VisibilityIndicator())
    
    private var progressIndicator: UIView!
    private var progressIndicatorTotal: UIView!

    private var progressIndicatorRight: NSLayoutConstraint!
    
    private var visibilityIndicatorRight: NSLayoutConstraint!
    
    private var scrollViewContentLeft: NSLayoutConstraint!
    private var scrollViewContentRight: NSLayoutConstraint!
    
    public init(model: TopbarModel) {
        self.topbarModel = model
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
            let topbarComponent = self.topbarModel.get(i)
            let topbarComponentContainer = TopbarComponentView(
                component: topbarComponent,
                action: UIAction(title: "Skip to i") { _ in
                    self.updateCurrentSelection(i)
                    self.topbarModel.setSelectedItem(item: i)
                }
            )
            
            
            self.scrollView.addSubview(topbarComponentContainer)
            topbarComponentContainer.translatesAutoresizingMaskIntoConstraints = false
            
            if self.topbarModel.getSelectedItem() == i {
                topbarComponentContainer.toggleActive()
            }
            
            NSLayoutConstraint.activate([
                topbarComponentContainer.topAnchor.constraint(equalTo: self.scrollView.safeAreaLayoutGuide.topAnchor),
                self.scrollView.contentLayoutGuide.heightAnchor.constraint(greaterThanOrEqualTo: topbarComponentContainer.heightAnchor),
            ])
            
            
            topbarComponentContainer.setContentHuggingPriority(.required, for: .vertical)
            topbarComponentContainer.setContentHuggingPriority(.required, for: .horizontal)
        }
        
        
        self.scrollView.backgroundColor = UIColor.systemBackground
        
        for i in 1..<self.scrollView.subviews.count {
            guard let viewForLogoPrev = (self.scrollView.subviews[i-1] as? any AnyTopbarComponentView)?.viewForLogo() else { continue }
            guard let viewForLogoCurrent = (self.scrollView.subviews[i] as? any AnyTopbarComponentView)?.viewForLogo() else { continue }
 
            NSLayoutConstraint.activate([
                viewForLogoCurrent.leftAnchor.constraint(equalTo: viewForLogoPrev.safeAreaLayoutGuide.rightAnchor, constant: 60),
            ])
        }
        
        NSLayoutConstraint.activate([
            self.scrollView.contentLayoutGuide.leftAnchor.constraint(equalTo: self.scrollView.subviews.first!.leftAnchor, constant: -5),
            self.scrollView.contentLayoutGuide.rightAnchor.constraint(greaterThanOrEqualTo: self.scrollView.subviews.last!.rightAnchor)
        ])

        
        // MARK: - PROGRESS MARKERS
        let progressIndicatorTotal: UIView = .init()
        progressIndicatorTotal.backgroundColor = disabledColor.withAlphaComponent(0.2)
        
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
        progressIndicatorCurrent.backgroundColor = UIColor.purple
        
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
        
        self.addSubview(visibilityIndicator.view)
        
        self.visibilityIndicator.view.translatesAutoresizingMaskIntoConstraints = false
        
        if let viewForLogoCurrent = (self.scrollView.subviews[self.topbarModel.getSelectedItem()] as? any AnyTopbarComponentView)?.viewForLogo()  {
            NSLayoutConstraint.activate([
                self.visibilityIndicator.view.centerYAnchor.constraint(equalTo: viewForLogoCurrent.centerYAnchor, constant: -20)
            ])
            
            self.visibilityIndicatorRight = self.visibilityIndicator.view.centerXAnchor.constraint(equalTo: viewForLogoCurrent.centerXAnchor, constant: 20)
            self.visibilityIndicatorRight.isActive = true
        }

        
        self.visibilityIndicator.view.setContentHuggingPriority(.required, for: .vertical)
        self.visibilityIndicator.view.setContentHuggingPriority(.required, for: .horizontal)
        
        self.visibilityIndicator.view.backgroundColor = .clear
        
        self.topbarModel.onItemsReplaced(self.onItemsChanged(_:))
        self.topbarModel.onSelectedItemChanged(self.updateCurrentSelection(_:))
        self.topbarModel.onRedactedChange(self.onRedacted(_:))
    }
    
    required public init?(coder: NSCoder) {
        fatalError()
    }
    
    
    public final func updateCurrentSelection(_ index: Int) {
        assert(index >= 0 && index < self.scrollView.subviews.count)
        let previousIndex = self.topbarModel.getSelectedItem()
        
        if index != self.topbarModel.getSelectedItem() {
            self.topbarModel.setSelectedItem(item: index)
        }
        
        if let previousLabel = self.nthComponentView(index) {
            previousLabel.toggleActive()
        }
        
        if let currentItem = self.nthComponentView(index) {
            currentItem.toggleActive()
            
            UIView.animate(withDuration: 0.25) {
                self.progressIndicatorRight.isActive = false
                self.progressIndicatorRight = self.progressIndicator.rightAnchor.constraint(equalTo: currentItem.viewForLogo()!.safeAreaLayoutGuide.centerXAnchor)
                self.progressIndicatorRight.isActive = true
                
                self.superview?.layoutIfNeeded()
            }
            
            UIView.animate(withDuration: 0.125) {
                self.visibilityIndicator.view.layer.opacity = 0.0
            } completion: { _ in
                self.visibilityIndicatorRight.isActive = false
                self.visibilityIndicatorRight = self.visibilityIndicator.view.centerXAnchor.constraint(
                    equalTo: currentItem.viewForLogo()!.safeAreaLayoutGuide.centerXAnchor,
                    constant: 40 - 13
                )
                self.visibilityIndicatorRight.isActive = true
                
                UIView.animate(withDuration: 0.25) {
                    self.visibilityIndicator.view.layer.opacity = 1.0
                }
            }
        }

        self.scrollView.centerScrollContent(self.nthComponentView(self.topbarModel.getSelectedItem())!)
    }
    
    
    public final func viewDidTransition(to size: CGSize) {
        self.scrollView.centerScrollContent(self.scrollView.subviews[self.topbarModel.getSelectedItem()])
    }
    
    
    @MainActor private final func onItemsChanged(_ items: [any TopbarComponent]) {
        self.scrollView.removeAllConstraints()
        self.removeAllSubviewsConstraints()
        
        self.translatesAutoresizingMaskIntoConstraints = false
        self.scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        self.progressIndicatorTotal.removeFromSuperview()
        self.progressIndicator.removeFromSuperview()
        
        self.progressIndicatorRight.isActive = false
        
        self.scrollView.subviews.forEach { subview in
            subview.removeFromSuperview()
        }
        
        self.scrollView.removeFromSuperview()
        
        self.scrollView = UIScrollView(frame: .zero)
        self.scrollView.translatesAutoresizingMaskIntoConstraints = false
        self.scrollView.showsHorizontalScrollIndicator = false
        
        self.addSubview(self.scrollView)
                
        NSLayoutConstraint.activate([
            self.scrollView.leftAnchor.constraint(equalTo: self.safeAreaLayoutGuide.leftAnchor),
            self.scrollView.rightAnchor.constraint(equalTo: self.safeAreaLayoutGuide.rightAnchor),
            self.scrollView.bottomAnchor.constraint(equalTo: self.safeAreaLayoutGuide.bottomAnchor),
            self.scrollView.topAnchor.constraint(equalTo: self.safeAreaLayoutGuide.topAnchor),
            self.scrollView.heightAnchor.constraint(equalTo: self.scrollView.contentLayoutGuide.heightAnchor)
        ])
        
        for i in 0..<self.topbarModel.count() {
            let topbarComponent = self.topbarModel.get(i)
            let topbarComponentContainer = TopbarComponentView(
                component: topbarComponent,
                action: UIAction(title: "Skip to i") { _ in
                    self.updateCurrentSelection(i)
                }
            )
            
            self.scrollView.addSubview(topbarComponentContainer)
            topbarComponentContainer.translatesAutoresizingMaskIntoConstraints = false
            
            if self.topbarModel.getSelectedItem() == i {
                topbarComponentContainer.toggleActive()
            }
            
            NSLayoutConstraint.activate([
                topbarComponentContainer.topAnchor.constraint(equalTo: self.scrollView.safeAreaLayoutGuide.topAnchor),
                self.scrollView.heightAnchor.constraint(greaterThanOrEqualTo: topbarComponentContainer.heightAnchor),
            ])
            
            
            topbarComponentContainer.setContentHuggingPriority(.required, for: .vertical)
            topbarComponentContainer.setContentHuggingPriority(.required, for: .horizontal)
        }
        
        
        for i in 1..<self.scrollView.subviews.count {
            guard let viewForLogoPrev = (self.scrollView.subviews[i-1] as? any AnyTopbarComponentView)?.viewForLogo() else { continue }
            guard let viewForLogoCurrent = (self.scrollView.subviews[i] as? any AnyTopbarComponentView)?.viewForLogo() else { continue }
            NSLayoutConstraint.activate([
                viewForLogoCurrent.leftAnchor.constraint(equalTo: viewForLogoPrev.rightAnchor, constant: 60),
            ])
        }

        
        if let firstComponent = self.firstComponentView() {
            NSLayoutConstraint.activate([
                self.scrollView.contentLayoutGuide.leftAnchor.constraint(lessThanOrEqualTo: firstComponent.leftAnchor, constant: -5)
            ])
        } else {
            fatalError()
        }
        
        if let lastComponent = self.lastComponentView() {
            NSLayoutConstraint.activate([
                self.scrollView.contentLayoutGuide.rightAnchor.constraint(greaterThanOrEqualTo: lastComponent.rightAnchor)
            ])
        } else {
            fatalError()
        }
     
        self.scrollView.centerScrollContent(self.scrollView.subviews[self.topbarModel.getSelectedItem()])
        
        self.scrollView.backgroundColor = .systemBackground
        
        self.scrollView.addSubview(self.progressIndicator)
        self.progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        if let viewForLogoFirst = self.firstComponentView()?.viewForLogo() {
            NSLayoutConstraint.activate([
                self.progressIndicator.leftAnchor.constraint(equalTo: viewForLogoFirst.safeAreaLayoutGuide.centerXAnchor),
                self.progressIndicator.centerYAnchor.constraint(equalTo: viewForLogoFirst.safeAreaLayoutGuide.centerYAnchor),
                self.progressIndicator.heightAnchor.constraint(equalToConstant: 1)
            ])
        }
        
        if let viewForLogoCurrent = self.nthComponentView(self.topbarModel.getSelectedItem())?.viewForLogo()  {
            self.progressIndicatorRight = self.progressIndicator.rightAnchor.constraint(equalTo: viewForLogoCurrent.safeAreaLayoutGuide.centerXAnchor)
            self.progressIndicatorRight.isActive = true
        }

        self.scrollView.addSubview(self.progressIndicatorTotal)
        self.progressIndicatorTotal.translatesAutoresizingMaskIntoConstraints = false
        
        if let viewForLogoFirst = self.firstComponentView()?.viewForLogo() {
            if let viewForLogosLast = self.lastComponentView()?.viewForLogo() {
                NSLayoutConstraint.activate([
                    progressIndicatorTotal.leftAnchor.constraint(equalTo: viewForLogoFirst.safeAreaLayoutGuide.centerXAnchor),
                    progressIndicatorTotal.centerYAnchor.constraint(equalTo: viewForLogoFirst.safeAreaLayoutGuide.centerYAnchor),
                    progressIndicatorTotal.rightAnchor.constraint(equalTo: viewForLogosLast.safeAreaLayoutGuide.centerXAnchor),
                    progressIndicatorTotal.heightAnchor.constraint(equalToConstant: 1)
                ])
            }
        }

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

    
    private final func onRedacted(_ isRedacted: Bool) {
        self.scrollView.subviews.compactMap { subview in
            return subview as? any AnyTopbarComponentView
        }.forEach { subview in
            subview.setIsRedacted(isRedacted)
        }
    }
}
