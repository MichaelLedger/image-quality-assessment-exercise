import UIKit
import Photos

class PhotoCollectionViewController: UIViewController {
    
    private var collectionView: UICollectionView!
    private let cellIdentifier = "PhotoCell"
    var photos: [ScoredPhoto] = []
    private let imageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 50  // Maximum number of images to keep in memory
        cache.totalCostLimit = 50 * 1024 * 1024  // 50MB limit
        return cache
    }()
    
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
        layout.itemSize = CGSize(width: width, height: width)
        
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
            cell.configure(with: image, score: photo.score)
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
            photo.loadAssetImage { [weak self] image in
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
    private let scoreBackground = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
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
        
        // Setup score background
        scoreBackground.layer.cornerRadius = 4
        scoreBackground.clipsToBounds = true
        contentView.addSubview(scoreBackground)
        
        // Setup score label
        scoreLabel.textColor = .white
        scoreLabel.font = .systemFont(ofSize: 12, weight: .medium)
        scoreLabel.textAlignment = .center
        contentView.addSubview(scoreLabel)
        
        // Position score elements
        let padding: CGFloat = 4
        let labelSize = CGSize(width: 50, height: 20)
        scoreBackground.frame = CGRect(x: contentView.bounds.width - labelSize.width - padding,
                                     y: padding,
                                     width: labelSize.width,
                                     height: labelSize.height)
        scoreLabel.frame = scoreBackground.frame
        
        scoreBackground.autoresizingMask = [.flexibleLeftMargin, .flexibleBottomMargin]
        scoreLabel.autoresizingMask = [.flexibleLeftMargin, .flexibleBottomMargin]
    }
    
    func configure(with image: UIImage, score: Double) {
        imageView.image = image
        scoreLabel.text = String(format: "%.2f", score)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        scoreLabel.text = nil
        activityIndicator.stopAnimating()
    }
    
    func showLoadingState() {
        imageView.image = nil
        activityIndicator.startAnimating()
        scoreBackground.isHidden = true
        scoreLabel.isHidden = true
    }
    
    func hideLoadingState() {
        activityIndicator.stopAnimating()
        scoreBackground.isHidden = false
        scoreLabel.isHidden = false
    }
}
