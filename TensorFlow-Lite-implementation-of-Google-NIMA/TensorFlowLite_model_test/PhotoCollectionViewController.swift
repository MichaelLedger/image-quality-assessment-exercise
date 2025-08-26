import UIKit
import Photos

class PhotoCollectionViewController: UIViewController {
    
    private var collectionView: UICollectionView!
    private let cellIdentifier = "PhotoCell"
    var photos: [ScoredPhoto] = []
    private var cellSize: CGSize = .zero
    private let imageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 50  // Maximum number of images to keep in memory
        cache.totalCostLimit = 50 * 1024 * 1024  // 50MB limit
        return cache
    }()
    
    private var labelCache: [String: String] = [:]  // Cache for photo labels
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Scored Photos"
        
        // Setup collection view layout
        let layout = UICollectionViewFlowLayout()
        let spacing: CGFloat = 1
        layout.minimumInteritemSpacing = spacing
        layout.minimumLineSpacing = spacing
        
        // Calculate cell size (3 columns with spacing)
        let width = (view.bounds.width - spacing * 2) / 3
        cellSize = CGSize(width: width, height: width)
        layout.itemSize = cellSize
        //print("cell size==\(cellSize)")
        
        // Create collection view
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemBackground
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.delegate = self
        collectionView.dataSource = self
        view.addSubview(collectionView)
        
        // Register cell
        collectionView.register(PhotoCell.self, forCellWithReuseIdentifier: cellIdentifier)
    }
}

// MARK: - UICollectionViewDataSource
extension PhotoCollectionViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photos.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellIdentifier, for: indexPath) as! PhotoCell
        let photo = photos[indexPath.item]
        
        // Get cache key
        let cacheKey = (photo.assetIdentifier ?? photo.localImageName ?? "\(indexPath.item)") as NSString
        
        // Function to configure cell and cache image
        let configureCell = { [weak self] (image: UIImage) in
            guard let self = self else { return }
            //print("cell imgee loaded==\(image.cgImage?.width ?? 0)*\(image.cgImage?.height ?? 0)")
            // Get label from photo
            let label = photo.label?.description
            cell.configure(with: image, score: photo.score, label: label)
            self.imageCache.setObject(image, forKey: cacheKey, cost: Int(image.size.width * image.size.height * 4))
        }
        
        // Try to get image from cache first
        if let cachedImage = imageCache.object(forKey: cacheKey) {
            configureCell(cachedImage)
        } else if let bundleImage = photo.image {
            // For local images
            configureCell(bundleImage)
        } else {
            // Show placeholder or loading state
            cell.showLoadingState()
            
            // Load asset image
            // Use cell size as target size for better memory efficiency
            let scale = UIScreen.main.scale
            photo.loadAssetImage(targetSize: CGSize(width: self.cellSize.width * scale, height: self.cellSize.height * scale)) { [weak self] image in
                guard let self = self,
                      let image = image,
                      let visibleCell = self.collectionView.cellForItem(at: indexPath) as? PhotoCell else { return }
                DispatchQueue.main.async {
                    visibleCell.hideLoadingState()
                    configureCell(image)
                }
            }
        }
        
        return cell
    }
}

// MARK: - UICollectionViewDelegate
extension PhotoCollectionViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Show full screen preview
        let photo = photos[indexPath.item]
        let previewVC = PhotoPreviewViewController()
        previewVC.scoredPhoto = photo
        navigationController?.pushViewController(previewVC, animated: true)
    }
}

// MARK: - PhotoCell
class PhotoCell: UICollectionViewCell {
    private let imageView = UIImageView()
    private let scoreLabel = UILabel()
    private let labelLabel = UILabel()
    private let scoreBackground = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    private let labelBackground = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        // Setup image view
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        contentView.addSubview(imageView)
        imageView.frame = contentView.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Setup activity indicator
        activityIndicator.hidesWhenStopped = true
        contentView.addSubview(activityIndicator)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
        
        // Setup score background and label
        scoreBackground.layer.cornerRadius = 4
        scoreBackground.clipsToBounds = true
        contentView.addSubview(scoreBackground)
        
        scoreLabel.textColor = .white
        scoreLabel.font = .systemFont(ofSize: 12, weight: .medium)
        scoreLabel.textAlignment = .center
        contentView.addSubview(scoreLabel)
        
        // Setup label background and label
        labelBackground.layer.cornerRadius = 4
        labelBackground.clipsToBounds = true
        contentView.addSubview(labelBackground)
        
        labelLabel.textColor = .white
        labelLabel.font = .systemFont(ofSize: 12, weight: .medium)
        labelLabel.textAlignment = .center
        contentView.addSubview(labelLabel)
        
        // Position elements
        let padding: CGFloat = 4
        let elementHeight: CGFloat = 20
        let scoreWidth: CGFloat = 50
        let labelWidth: CGFloat = 80
        
        // Position score at top right
        scoreBackground.frame = CGRect(
            x: contentView.bounds.width - scoreWidth - padding,
            y: padding,
            width: scoreWidth,
            height: elementHeight
        )
        scoreLabel.frame = scoreBackground.frame
        
        // Position label at bottom
        labelBackground.frame = CGRect(
            x: (contentView.bounds.width - labelWidth) / 2,
            y: contentView.bounds.height - elementHeight - padding,
            width: labelWidth,
            height: elementHeight
        )
        labelLabel.frame = labelBackground.frame
        
        // Setup autoresizing masks
        scoreBackground.autoresizingMask = [.flexibleLeftMargin, .flexibleBottomMargin]
        scoreLabel.autoresizingMask = [.flexibleLeftMargin, .flexibleBottomMargin]
        labelBackground.autoresizingMask = [.flexibleLeftMargin, .flexibleTopMargin, .flexibleRightMargin]
        labelLabel.autoresizingMask = [.flexibleLeftMargin, .flexibleTopMargin, .flexibleRightMargin]
    }
    
    func configure(with image: UIImage, score: Double, label: String? = nil) {
        imageView.image = image
        scoreLabel.text = String(format: "%.2f", score)
        
        if let label = label {
            labelLabel.text = label
            labelBackground.isHidden = false
            labelLabel.isHidden = false
        } else {
            labelBackground.isHidden = true
            labelLabel.isHidden = true
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        scoreLabel.text = nil
        labelLabel.text = nil
        activityIndicator.stopAnimating()
    }
    
    func showLoadingState() {
        imageView.image = nil
        activityIndicator.startAnimating()
        scoreBackground.isHidden = true
        scoreLabel.isHidden = true
        labelBackground.isHidden = true
        labelLabel.isHidden = true
    }
    
    func hideLoadingState() {
        activityIndicator.stopAnimating()
        scoreBackground.isHidden = false
        scoreLabel.isHidden = false
        // Label visibility is handled in configure
    }
}
