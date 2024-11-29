
import Foundation
import UIKit
import Combine
import ZTronObservation


protocol ReadMoreLessViewDelegate: AnyObject {
    func didChangeState(_ readMoreLessView: CaptionView)
}

@IBDesignable public final class CaptionView : UIView, Component, AnyCaptionView {
    public let id: String = "captions"
    nonisolated lazy private var subscription: AnyCancellable? = nil
    nonisolated lazy private var interactionsDelegate: (any MSAInteractionsManager)? = nil {
        didSet {
            guard let interactionsDelegate = self.interactionsDelegate else { return }
            interactionsDelegate.setup(or: .ignore)
        }
        
        willSet {
            guard let interactionsDelegate = self.interactionsDelegate else { return }
            interactionsDelegate.detach(or: .ignore)
        }
    }
        
    
    @IBInspectable var maxNumberOfLinesCollapsed: Int = 3
    nonisolated fileprivate lazy var kvoContext = 0
        
    @IBInspectable var bodyColor: UIColor = .darkGray {
        didSet{
            bodyLabel.textColor = bodyColor
        }
    }
    
    @IBInspectable var buttonColor: UIColor = .orange {
        didSet{
            moreLessButton.setTitleColor(buttonColor, for: UIControl.State())
        }
    }
    
    @IBInspectable var cornerRadius: CGFloat = 0.0 {
        didSet{
             layer.cornerRadius = cornerRadius
        }
    }
        
    @IBInspectable var bodyLabelFont: UIFont = .systemFont(ofSize: 14) {
        didSet{
            bodyLabel.font = bodyLabelFont
        }
    }
    
    @IBInspectable var moreLessButtonFont: UIFont = .systemFont(ofSize: 12) {
        didSet{
            moreLessButton.titleLabel!.font = moreLessButtonFont as UIFont
        }
    }
    
    var moreText = NSLocalizedString("SHOW MORE", comment: "Show More")
    var lessText = NSLocalizedString("SHOW LESS", comment: "Show Less")

    fileprivate enum ReadMoreLessViewState {
        case collapsed
        case expanded
        
        mutating func toggle() {
            switch self {
            case .collapsed:
                self = .expanded
            case .expanded:
                self = .collapsed
            }
        }
    }
    
    weak var delegate: ReadMoreLessViewDelegate?
    
    fileprivate var state: ReadMoreLessViewState = .collapsed {
        didSet {
            switch state {
            case .collapsed:
                bodyLabel.lineBreakMode = .byTruncatingTail
                bodyLabel.numberOfLines = maxNumberOfLinesCollapsed
                moreLessButton.setTitle(moreText, for: UIControl.State())
            case .expanded:
                bodyLabel.lineBreakMode = .byWordWrapping
                bodyLabel.numberOfLines = 0
                moreLessButton.setTitle(lessText, for: UIControl.State())
            }
            
            delegate?.didChangeState(self)
        }
    }
    
    @objc func buttonTouched(_ sender: UIButton) {
        state.toggle()
    }
    
    lazy fileprivate var moreLessButton: UIButton! = {
        let button = UIButton(frame: CGRect.zero)
        button.backgroundColor = UIColor.clear
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(CaptionView.buttonTouched(_:)), for: .touchUpInside)
        button.setTitleColor(.orange, for: UIControl.State())
        return button
    }()
    
    lazy fileprivate var bodyLabel: UIBoundsObservableView! = {
        let label = UIBoundsObservableView(frame: CGRect.zero)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.textColor = .black
        
        return label
    }()
    
    
    // MARK: Initialisers
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureViews()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configureViews()
    }
    
    
    fileprivate func initComponents() {
        bodyLabel.font = bodyLabelFont
        bodyLabel.textColor = bodyColor
        
        moreLessButton.titleLabel!.font = moreLessButtonFont
        moreLessButton.setTitleColor(buttonColor, for: UIControl.State())
        
        self.subscription = self.bodyLabel.boundsPublisher.receive(on: RunLoop.main).sink(receiveCompletion: { completion in
            self.subscription?.cancel()
        }, receiveValue: { bounds in
            if self.countLabelLines(label: self.bodyLabel) <= self.maxNumberOfLinesCollapsed {
                self.moreLessButton.isHidden = true
            }
        })
        
    }
    
    // MARK: Private
    
    fileprivate func configureViews() {
        state = .collapsed
        
        addSubview(bodyLabel)
        addSubview(moreLessButton)
        
        let views = ["bodyLabel": bodyLabel, "moreLessButton": moreLessButton] as [String : UIView]
        let horizontalConstraintsBody = NSLayoutConstraint.constraints(withVisualFormat: "H:|-6-[bodyLabel]-6-|", options: .alignAllLastBaseline, metrics: nil, views: views)
        let horizontalConstraintsButton = NSLayoutConstraint.constraints(withVisualFormat: "H:|-6-[moreLessButton]-6-|", options: .alignAllLastBaseline, metrics: nil, views: views)
        let verticalConstraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|-6-[bodyLabel]-4-[moreLessButton]-4-|", options: NSLayoutConstraint.FormatOptions(rawValue: 0), metrics: nil, views: views)
        NSLayoutConstraint.activate(horizontalConstraintsBody + horizontalConstraintsButton + verticalConstraints)
        
        initComponents()
    }
    
    public func setText(body: String) {
        guard let bodyLabel = bodyLabel else { return }
        bodyLabel.text = body
        
        if body.isEmpty {
            moreLessButton.isHidden = true
            moreLessButton.isEnabled = false
        } else {
            moreLessButton.isHidden = false
            moreLessButton.isEnabled = true
        }
        
        if countLabelLines(label: bodyLabel) <= maxNumberOfLinesCollapsed {
            moreLessButton.isHidden = true
        }
    }
        
    fileprivate func countLabelLines(label: UILabel) -> Int {
        layoutIfNeeded()
        
        guard let text = label.text else { return 0 }
        
        let myText = text as NSString
        let attributes = [NSAttributedString.Key.font : label.font as UIFont]
        let labelSize = myText.boundingRect(with: CGSize(width: label.bounds.width, height: CGFloat.greatestFiniteMagnitude), options: NSStringDrawingOptions.usesLineFragmentOrigin, attributes: attributes, context: nil)
        return Int(ceil(CGFloat(labelSize.height) / label.font.lineHeight))
    }
    
    deinit {
        MainActor.assumeIsolated {
            self.subscription?.cancel()
        }
    }
        
    nonisolated public func getDelegate() -> (any ZTronObservation.InteractionsManager)? {
        return self.interactionsDelegate
    }
    
    nonisolated public func setDelegate(_ interactionsManager: (any ZTronObservation.InteractionsManager)?) {
        guard let interactionsManager = (interactionsManager as? MSAInteractionsManager) else {
            if interactionsManager == nil {
                self.interactionsDelegate = nil
            } else {
                fatalError("Expected interactions manager of type \(String(describing: MSAInteractionsManager.self)), in \(#function) @ \(#file)")
            }
            
            return
        }
        
        self.interactionsDelegate = interactionsManager
    }


}
