import UIKit

class PhotoPreviewViewController: UIViewController {
    
    var scoredPhoto: ScoredPhoto?
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    
    private let imageView = UIImageView()
    private let scoreLabel = UILabel()
    private let labelLabel = UILabel()
    private let locationLabel = UILabel()
    private let scoreBackground = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    private let labelBackground = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    private let locationBackground = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        
        // Add share button
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .action,
            target: self,
            action: #selector(sharePhoto)
        )
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
        
        // Setup score elements
        scoreBackground.layer.cornerRadius = 8
        scoreBackground.clipsToBounds = true
        view.addSubview(scoreBackground)
        
        scoreLabel.textColor = .white
        scoreLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        scoreLabel.textAlignment = .center
        if let score = scoredPhoto?.score {
            scoreLabel.text = String(format: "Score: %.2f", score)
        }
        view.addSubview(scoreLabel)
        
        // Setup label elements
        
        // Calculate offsets and sizes
        let elementSize = CGSize(width: 120, height: 40)
        let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        let window = windowScene?.windows.first(where: { $0.isKeyWindow })
        let topPadding = window?.safeAreaInsets.top ?? 0
        let navHeight = navigationController?.navigationBar.frame.height ?? 0
        
        // Position label at top left
        labelBackground.frame = CGRect(
            x: 0,
            y: topPadding + navHeight,
            width: elementSize.width,
            height: elementSize.height
        )
        labelBackground.layer.cornerRadius = 8
        labelBackground.clipsToBounds = true
        view.addSubview(labelBackground)
        
        labelLabel.textColor = .white
        labelLabel.font = .systemFont(ofSize: 16, weight: .medium)
        labelLabel.textAlignment = .center
        labelLabel.numberOfLines = 0
        view.addSubview(labelLabel)
        var labelSize = CGSize.zero
        if let label = scoredPhoto?.label {
            labelLabel.text = label
            labelSize = labelLabel.sizeThatFits(CGSizeMake(self.view.bounds.size.width - 8 * 2, CGFloat.greatestFiniteMagnitude))
        }
        labelLabel.frame = CGRect(
            x: 8,
            y: topPadding + navHeight + 8,
            width: labelSize.width,
            height: labelSize.height
        )
        
        // Setup location elements
        locationBackground.layer.cornerRadius = 8
        locationBackground.clipsToBounds = true
        locationBackground.alpha = 0.5
        view.addSubview(locationBackground)
        
        locationLabel.textColor = .white
        locationLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        locationLabel.textAlignment = .center
        locationLabel.numberOfLines = 2
        if let location = scoredPhoto?.locationName {
            locationLabel.text = location
        }
        view.addSubview(locationLabel)
        
        // Position score at top right
        scoreBackground.frame = CGRect(
            x: view.bounds.width - elementSize.width,
            y: topPadding + navHeight,
            width: elementSize.width,
            height: elementSize.height
        )
        scoreLabel.frame = scoreBackground.frame
        
        labelBackground.frame.size.width = labelLabel.bounds.size.width + 8 * 2
        labelBackground.frame.size.height = labelLabel.bounds.size.height + 8 * 2
        labelBackground.frame.origin.y = self.view.bounds.size.height - labelBackground.frame.size.height - 8 //CGRectGetMaxY(scoreBackground.frame) + 8
        labelBackground.frame.origin.x = (self.view.bounds.size.width - labelBackground.frame.size.width) / 2.0
        labelLabel.center = labelBackground.center
        
        // Position location below label
        locationBackground.frame = CGRect(
            x: 0,
            y: topPadding + navHeight + elementSize.height + 8,
            width: elementSize.width * 2,
            height: elementSize.height
        )
        locationLabel.frame = locationBackground.frame
        
        // Setup autoresizing masks
        scoreBackground.autoresizingMask = [.flexibleLeftMargin, .flexibleBottomMargin]
        scoreLabel.autoresizingMask = [.flexibleLeftMargin, .flexibleBottomMargin]
        labelBackground.autoresizingMask = [.flexibleRightMargin, .flexibleBottomMargin]
        labelLabel.autoresizingMask = [.flexibleRightMargin, .flexibleBottomMargin]
        locationBackground.autoresizingMask = [.flexibleRightMargin, .flexibleBottomMargin, .flexibleWidth]
        locationLabel.autoresizingMask = [.flexibleRightMargin, .flexibleBottomMargin, .flexibleWidth]
        
        loadImage()
    }
    
    private func loadImage() {
        guard let photo = scoredPhoto else { return }
        
        // Show loading indicator
        activityIndicator.startAnimating()
        scoreBackground.isHidden = true
        scoreLabel.isHidden = true
        labelBackground.isHidden = true
        labelLabel.isHidden = true
        locationBackground.isHidden = true
        locationLabel.isHidden = true
        
        if let bundleImage = photo.image {
            // Load local image
            imageView.image = bundleImage
            activityIndicator.stopAnimating()
            scoreBackground.isHidden = false
            scoreLabel.isHidden = false
            labelBackground.isHidden = labelLabel.text == nil
            labelLabel.isHidden = labelLabel.text == nil
            locationBackground.isHidden = locationLabel.text == nil
            locationLabel.isHidden = locationLabel.text == nil
        } else {
            // Load asset image in high quality
            // Calculate target size based on screen bounds for high quality
//            let screenSize = UIScreen.main.bounds.size
//            let targetSize = CGSize(
//                width: max(screenSize.width, screenSize.height),
//                height: max(screenSize.width, screenSize.height)
//            )
            photo.loadAssetImage(targetSize: .zero) { [weak self] image in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.imageView.image = image
                    self.activityIndicator.stopAnimating()
                    self.scoreBackground.isHidden = false
                    self.scoreLabel.isHidden = false
                    self.labelBackground.isHidden = self.labelLabel.text == nil
                    self.labelLabel.isHidden = self.labelLabel.text == nil
                    self.locationBackground.isHidden = self.locationLabel.text == nil
                    self.locationLabel.isHidden = self.locationLabel.text == nil
                }
            }
        }
    }
    
    @objc private func sharePhoto() {
        guard let image = imageView.image else { return }
        
        var activityItems: [Any] = [image]
        
        // Add score text if available
        if let score = scoredPhoto?.score {
            activityItems.append("Photo Score: \(String(format: "%.2f", score))")
        }
        
        // Add label text if available
        if let label = scoredPhoto?.label?.description {
            activityItems.append("Photo Label: \(label)")
        }
        
        // Add location text if available
        if let location = scoredPhoto?.locationName {
            activityItems.append("Location: \(location)")
        }
        
        let activityVC = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        
        // For iPad
        if let popoverController = activityVC.popoverPresentationController {
            popoverController.barButtonItem = navigationItem.rightBarButtonItem
        }
        
        present(activityVC, animated: true)
    }
}
