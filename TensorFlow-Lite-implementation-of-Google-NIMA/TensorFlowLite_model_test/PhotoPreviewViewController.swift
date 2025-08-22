import UIKit

class PhotoPreviewViewController: UIViewController {
    
    var scoredPhoto: ScoredPhoto?
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    
    private let imageView = UIImageView()
    private let scoreLabel = UILabel()
    private let scoreBackground = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
    }
    
    private func setupViews() {
        view.backgroundColor = .black
        
        // Setup image view
        imageView.contentMode = .scaleAspectFit
        view.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Setup activity indicator
        activityIndicator.color = .white
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        // Setup score background
        scoreBackground.layer.cornerRadius = 8
        scoreBackground.clipsToBounds = true
        view.addSubview(scoreBackground)
        
        // Setup score label
        scoreLabel.textColor = .white
        scoreLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        scoreLabel.textAlignment = .center
        if let score = scoredPhoto?.score {
            scoreLabel.text = String(format: "Score: %.2f", score)
        }
        view.addSubview(scoreLabel)
        
        // Position score elements
        let padding: CGFloat = 16
        let labelSize = CGSize(width: 120, height: 40)
        scoreBackground.frame = CGRect(x: view.bounds.width - labelSize.width - padding,
                                     y: view.safeAreaInsets.top + padding,
                                     width: labelSize.width,
                                     height: labelSize.height)
        scoreLabel.frame = scoreBackground.frame
        
        scoreBackground.autoresizingMask = [.flexibleLeftMargin, .flexibleBottomMargin]
        scoreLabel.autoresizingMask = [.flexibleLeftMargin, .flexibleBottomMargin]
        
        loadImage()
    }
    
    private func loadImage() {
        guard let photo = scoredPhoto else { return }
        
        // Show loading indicator
        activityIndicator.startAnimating()
        scoreBackground.isHidden = true
        scoreLabel.isHidden = true
        
        if let bundleImage = photo.image {
            // Load local image
            imageView.image = bundleImage
            activityIndicator.stopAnimating()
            scoreBackground.isHidden = false
            scoreLabel.isHidden = false
        } else {
            // Load asset image in high quality
            photo.loadAssetImage { [weak self] image in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.imageView.image = image
                    self.activityIndicator.stopAnimating()
                    self.scoreBackground.isHidden = false
                    self.scoreLabel.isHidden = false
                }
            }
        }
    }
}
