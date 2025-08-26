import UIKit

class FloatingButton: UIButton {
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupButton()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
    }
    
    private func setupButton() {
        backgroundColor = .systemBlue
        layer.cornerRadius = 25 // Half of width/height for circular shape
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4
        layer.shadowOpacity = 0.3
        
        // Set image with configuration
        if #available(iOS 13.0, *) {
            let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
            let image = UIImage(systemName: "photo.stack", withConfiguration: config)
            setImage(image, for: .normal)
            tintColor = .white
        } else {
            setTitle("+", for: .normal)
            titleLabel?.font = .systemFont(ofSize: 30, weight: .medium)
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        animate(isPressed: true)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        animate(isPressed: false)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        animate(isPressed: false)
    }
    
    private func animate(isPressed: Bool) {
        UIView.animate(withDuration: 0.1, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction]) {
            self.transform = isPressed ? CGAffineTransform(scaleX: 0.95, y: 0.95) : .identity
            self.alpha = isPressed ? 0.9 : 1.0
        }
    }
}
