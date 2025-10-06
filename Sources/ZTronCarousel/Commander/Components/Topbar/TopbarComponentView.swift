import UIKit
import ZTronTheme

public final class TopbarComponentView: UIView, AnyTopbarComponentView {
    private var component: any TopbarComponent
    private var action: UIAction
    private let diameter: CGFloat
    private let theme: any ZTronTheme
    
    weak private var logoView: UIView? = nil
    weak private var titleView: UILabel? = nil
    weak private var itemContainer: UIView? = nil
    
    private var isActive: Bool = false
    
    public init(
        component: any TopbarComponent,
        action: UIAction,
        diameter: CGFloat = 40.0,
        theme: any ZTronTheme = ZTronThemeProvider.default()
    ) {
        self.component = component
        self.action = action
        self.diameter = diameter
        self.theme = theme
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
        
        self.itemContainer = topbarComponentContainer
        
        let topbarComponentImage: UIImageView = UIImageView(image: UIImage(named: self.component.getIcon()))
        topbarComponentImage.contentMode = .scaleAspectFit

        topbarComponentContainer.addSubview(topbarComponentImage)
        topbarComponentImage.translatesAutoresizingMaskIntoConstraints = false
        
        
        let title: UILabel = .init()
        title.text = self.component.getName()
        title.textColor = UIColor.fromTheme(self.theme.colorSet, color: \.disabled)
        title.numberOfLines = 2
        title.font = .systemFont(
            ofSize: 10,
            weight: .regular
        )
        
        title.adjustsFontSizeToFitWidth = false
        title.lineBreakMode = .byTruncatingTail

        title.textAlignment = .center
        title.lineBreakMode = .byWordWrapping
                    
        title.translatesAutoresizingMaskIntoConstraints = false
        
        topbarComponentContainer.addSubview(title)
        
        NSLayoutConstraint.activate([
            topbarComponentImage.heightAnchor.constraint(equalTo: topbarComponentImage.widthAnchor),
            topbarComponentImage.widthAnchor.constraint(equalToConstant: self.diameter),
            topbarComponentImage.centerXAnchor.constraint(equalTo: topbarComponentContainer.safeAreaLayoutGuide.centerXAnchor),
            
            topbarComponentContainer.topAnchor.constraint(equalTo: topbarComponentImage.topAnchor),
            topbarComponentContainer.widthAnchor.constraint(lessThanOrEqualToConstant: self.diameter * 2.0),
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
    }
    
    public final func viewForLogo() -> UIView? {
        return self.logoView
    }
    
    public final func viewForTitle() -> UILabel? {
        return self.titleView
    }
    
    public final func makeActive() {
        guard let label = self.titleView else { return }
        
        label.animate(
            font: .systemFont(ofSize: 12, weight: .bold),
            textColor: .label,
            duration: 0.25
        )

        self.isActive = true
    }
    
    public final func makeVisited() {
        guard let label = self.titleView else { return }

        label.animate(
            font: .systemFont(ofSize: 10, weight: .regular),
            textColor: UIColor.fromTheme(self.theme.colorSet, color: \.disabled),
            duration: 0.25
        )
        
        self.isActive = false
    }
    
    
    public func makeUnvisited() {
        guard let label = self.titleView else { return }

        label.animate(
            font: .systemFont(ofSize: 10, weight: .regular),
            textColor: UIColor.fromTheme(self.theme.colorSet, color: \.disabled),
            duration: 0.25
        )
        
        self.isActive = false
    }
    

    public func replaceModel(with model: any TopbarComponent) {
        self.viewForTitle()?.text = model.getName()
        
        if let logoView = self.viewForLogo() as? UIImageView {
            logoView.image = UIImage(named: model.getIcon())
            logoView.contentMode = .scaleAspectFit
            self.component = model
        } else {
            fatalError()
        }
        
        self.superview?.layoutIfNeeded()
    }
}

public protocol AnyTopbarComponentView: UIView {
    func viewForLogo() -> UIView?
    func viewForTitle() -> UILabel?
    func makeActive() -> Void
    func makeVisited() -> Void
    func makeUnvisited() -> Void
    func replaceModel(with model: any TopbarComponent) -> Void
}

public extension AnyTopbarComponentView {
    func makeVisited() -> Void {
        print("func \(#function) not implemented on type \(String(describing: self))")
    }
    
    func makeUnvisited() -> Void {
        print("func \(#function) not implemented on type \(String(describing: self))")
    }
}
