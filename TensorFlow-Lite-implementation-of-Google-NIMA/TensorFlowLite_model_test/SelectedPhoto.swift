import Photos
import UIKit

struct SelectedPhoto {
    let assetIdentifier: String?
    let localImageName: String?
    let creationDate: Date?
    let modificationDate: Date?
    private(set) var score: Double?
    
    mutating func updateScore(_ newScore: Double) {
        score = newScore
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
                completion(image)
            }
        } else if let name = localImageName {
            completion(UIImage(named: name))
        } else {
            completion(nil)
        }
    }
}
