import UIKit
import SkeletonView

public final class TopbarComponentView: UIView, AnyTopbarComponentView {
    private var component: any TopbarComponent
    private var action: UIAction
    private let disabledColor: UIColor = UIColor(red: 123.0/255.0, green: 123.0/255.0, blue: 123.0/255.0, alpha: 1.0)

    weak private var logoView: UIView? = nil
    weak private var titleView: UILabel? = nil
    
    
    private var isActive: Bool = false
    
    public init(component: any TopbarComponent, action: UIAction) {
        self.component = component
        self.action = action
        super.init(frame: .zero)

        setup()
    }
    
    public required init?(coder: NSCoder) {
        fatalError()
    }
    
    public final func setup() {
        let topbarComponentContainer: UIButton = .init(type: .system)
        topbarComponentContainer.addAction(self.action, for: .touchUpInside)

        self.addSubview(topbarComponentContainer)
        topbarComponentContainer.translatesAutoresizingMaskIntoConstraints = false
        
        
        let topbarComponentImage: UIImageView = UIImageView(image: UIImage(named: self.component.getIcon()))
        topbarComponentImage.contentMode = .scaleAspectFit

        topbarComponentContainer.addSubview(topbarComponentImage)
        topbarComponentImage.translatesAutoresizingMaskIntoConstraints = false
        
        
        let title: UILabel = .init()
        title.text = self.component.getName()
        title.textColor = self.disabledColor // self.currentIndex != i ? disabledColor : .label
        title.numberOfLines = 0
        title.font = .systemFont(
            ofSize: 10,
            weight: .regular
        ) // self.currentIndex != i ? .regular : .bold)
        
        
        title.textAlignment = .center
        title.lineBreakMode = .byWordWrapping
                    
        title.translatesAutoresizingMaskIntoConstraints = false
        
        topbarComponentContainer.addSubview(title)
        
        NSLayoutConstraint.activate([
            topbarComponentImage.heightAnchor.constraint(equalTo: topbarComponentImage.widthAnchor),
            topbarComponentImage.widthAnchor.constraint(equalToConstant: 40),
            topbarComponentImage.centerXAnchor.constraint(equalTo: topbarComponentContainer.safeAreaLayoutGuide.centerXAnchor),
            
            topbarComponentContainer.topAnchor.constraint(equalTo: topbarComponentImage.topAnchor),
            topbarComponentContainer.widthAnchor.constraint(lessThanOrEqualToConstant: 80),
        ])

        
        NSLayoutConstraint.activate([
            topbarComponentContainer.bottomAnchor.constraint(greaterThanOrEqualTo: title.bottomAnchor),
            topbarComponentContainer.leftAnchor.constraint(lessThanOrEqualTo: title.leftAnchor),
            topbarComponentContainer.rightAnchor.constraint(greaterThanOrEqualTo: title.rightAnchor),
            
            title.topAnchor.constraint(equalTo: topbarComponentImage.bottomAnchor, constant: 5),
            title.centerXAnchor.constraint(equalTo: topbarComponentImage.centerXAnchor),
        ])
        
        self.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            self.topAnchor.constraint(equalTo: topbarComponentContainer.topAnchor),
            self.rightAnchor.constraint(equalTo: topbarComponentContainer.rightAnchor),
            self.bottomAnchor.constraint(equalTo: topbarComponentContainer.bottomAnchor),
            self.leftAnchor.constraint(equalTo: topbarComponentContainer.leftAnchor),
        ])

        
        topbarComponentImage.layer.zPosition = 2.0
        topbarComponentContainer.layer.zPosition = 2.0
        self.layer.zPosition = 2.0
        
                
        self.logoView = topbarComponentImage
        self.titleView = title
        
        topbarComponentImage.isSkeletonable = true
        self.titleView?.isSkeletonable = true
    }
    
    public final func viewForLogo() -> UIView? {
        return self.logoView
    }
    
    public final func viewForTitle() -> UILabel? {
        return self.titleView
    }
    
    public final func toggleActive() {
        guard let label = self.titleView else { return }
        
        label.animate(
            font: self.isActive ?  .systemFont(ofSize: 10, weight: .regular) : .systemFont(ofSize: 12, weight: .bold),
            textColor: self.isActive ? self.disabledColor : .label,
            duration: 0.25
        )

        self.isActive.toggle()
    }
    
    public final func setIsRedacted(_ isRedacted: Bool) {
        if isRedacted {
            self.logoView?.showGradientSkeleton()
            self.titleView?.showGradientSkeleton()
        } else {
            self.logoView?.stopSkeletonAnimation()
            self.logoView?.hideSkeleton()
            
            self.titleView?.stopSkeletonAnimation()
            self.logoView?.hideSkeleton()
        }
    }
}

public protocol AnyTopbarComponentView: UIView {
    func viewForLogo() -> UIView?
    func viewForTitle() -> UILabel?
    func toggleActive() -> Void
    
    func setIsRedacted(_: Bool)
}
