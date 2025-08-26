import UIKit
import Photos

struct ScoredPhoto {
    let assetIdentifier: String?  // PHAsset local identifier
    let localImageName: String?   // Bundle image name
    let modificationDate: Date?   // For change detection
    let score: Double
    let label: String?      // Image classification label
    
    var image: UIImage? {
        if let localName = localImageName {
            return UIImage(named: localName)
        }
        return nil
    }
    
    func loadAssetImage(targetSize: CGSize = CGSize(width: 512, height: 512), completion: @escaping (UIImage?) -> Void) {
        guard let identifier = assetIdentifier else {
            completion(nil)
            return
        }
        
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = assets.firstObject else {
            completion(nil)
            return
        }

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.resizeMode = .exact
        options.isSynchronous = false
        
        // Scale up the target size for better quality on retina displays
        let scale = UIScreen.main.scale
        var scaledSize = CGSize(
            width: targetSize.width * scale,
            height: targetSize.height * scale
        )
        
        // Use maximum size if target size is zero
        if CGSizeEqualToSize(targetSize, .zero) {
            scaledSize = PHImageManagerMaximumSize
        }
        
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: scaledSize,
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            completion(image)
        }
    }
}
