import UIKit
import Photos

struct ScoredPhoto {
    let assetIdentifier: String?  // PHAsset local identifier
    let localImageName: String?   // Bundle image name
    let modificationDate: Date?   // For change detection
    let score: Double
    
    var image: UIImage? {
        if let localName = localImageName {
            return UIImage(named: localName)
        }
        return nil
    }
    
    func loadAssetImage(completion: @escaping (UIImage?) -> Void) {
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
        
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 512, height: 512),
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            completion(image)
        }
    }
}
