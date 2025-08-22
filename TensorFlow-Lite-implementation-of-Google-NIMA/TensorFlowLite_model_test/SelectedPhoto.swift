import Photos
import UIKit

struct SelectedPhoto {
    private static func resizeImageIfNeeded(_ image: UIImage) -> UIImage {
        // If image is already large enough, return as is
        if image.size.width >= 224 && image.size.height >= 224 {
            return image
        }
        
        // Calculate scale needed to make both dimensions >= 224
        let widthRatio = 224 / image.size.width
        let heightRatio = 224 / image.size.height
        let scale = max(widthRatio, heightRatio)
        
        let newSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage ?? image
    }
    let assetIdentifier: String?
    let localImageName: String?
    let creationDate: Date?
    let modificationDate: Date?
    private(set) var score: Double?
    private(set) var isUtility: Bool?
    
    mutating func updateScore(_ newScore: Double?, isUtility: Bool? = nil) {
        score = newScore
        self.isUtility = isUtility
    }
    
    static func fromAsset(_ asset: PHAsset) -> SelectedPhoto {
        return SelectedPhoto(
            assetIdentifier: asset.localIdentifier,
            localImageName: nil,
            creationDate: asset.creationDate,
            modificationDate: asset.modificationDate,
            score: nil
        )
    }
    
    init(assetIdentifier: String? = nil, localImageName: String? = nil, creationDate: Date? = nil, modificationDate: Date? = nil, score: Double? = nil) {
        self.assetIdentifier = assetIdentifier
        self.localImageName = localImageName
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.score = score
    }
    
    func loadImage(targetSize: CGSize = CGSize(width: 512, height: 512), completion: @escaping (UIImage?) -> Void) {
        if let identifier = assetIdentifier {
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
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                guard let image = image else {
                    completion(nil)
                    return
                }
                
                completion(Self.resizeImageIfNeeded(image))
            }
        } else if let name = localImageName, let image = UIImage(named: name) {
            completion(Self.resizeImageIfNeeded(image))
        } else {
            completion(nil)
        }
    }
}
