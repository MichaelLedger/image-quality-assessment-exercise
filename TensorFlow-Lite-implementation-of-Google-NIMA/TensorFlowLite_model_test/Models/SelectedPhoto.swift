import UIKit
import Photos
import CoreLocation

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
    private(set) var label: String?
    private(set) var isUtility: Bool?
    private(set) var locationName: String?
    private(set) var location: CLLocation?
    
    init(assetIdentifier: String?, localImageName: String?, creationDate: Date?, modificationDate: Date?, score: Double? = nil, label: String? = nil, isUtility: Bool? = nil, location: CLLocation? = nil, locationName: String? = nil) {
        self.assetIdentifier = assetIdentifier
        self.localImageName = localImageName
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.score = score
        self.label = label
        self.isUtility = isUtility
        self.location = location
        self.locationName = locationName
    }
    
    mutating func updateScore(_ score: Double?, isUtility: Bool? = nil) {
        self.score = score
        self.isUtility = isUtility
    }
    
    mutating func updateLabel(_ label: String?) {
        self.label = label
    }
    
    mutating func updateLocationName(_ name: String) {
        self.locationName = name
    }
    
    mutating func updateLocation(_ location: CLLocation) {
        self.location = location
    }
    
    static func fromAsset(_ asset: PHAsset) -> SelectedPhoto {
        var location: CLLocation? = nil
        if let assetLocation = asset.location {
            location = assetLocation
        }
        return SelectedPhoto(
            assetIdentifier: asset.localIdentifier,
            localImageName: nil,
            creationDate: asset.creationDate,
            modificationDate: asset.modificationDate,
            location: location
        )
    }
    
    func loadImage(targetSize: CGSize = .zero, completion: @escaping (UIImage?) -> Void) {
        if let localName = localImageName {
            completion(UIImage(named: localName))
            return
        }
        
        guard let identifier = assetIdentifier else {
            completion(nil)
            return
        }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.resizeMode = .exact
        
        let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject
        
        let finalTargetSize = targetSize == .zero ? PHImageManagerMaximumSize : targetSize
        
        PHImageManager.default().requestImage(
            for: asset!,
            targetSize: finalTargetSize,
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            completion(image)
        }
    }
    
    func loadImage(targetSize: CGSize = CGSize(width: 512, height: 512)) async -> UIImage? {
        if let identifier = assetIdentifier {
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
            guard let asset = assets.firstObject else {
                return nil
            }
            
            // Scale up the target size for better quality on retina displays
            let scale = await UIScreen.main.scale
            var scaledSize = CGSize(
                width: targetSize.width * scale,
                height: targetSize.height * scale
            )
            
            // Use maximum size if target size is zero
            if CGSizeEqualToSize(targetSize, .zero) {
                scaledSize = PHImageManagerMaximumSize
            }
            
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.resizeMode = .exact
            options.isSynchronous = true  // Make the request synchronous for async/await pattern
            
            let result: UIImage? = await withCheckedContinuation { continuation in
                PHImageManager.default().requestImage(
                    for: asset,
                    targetSize: scaledSize,
                    contentMode: .aspectFit,
                    options: options
                ) { image, _ in
                    if let image = image {
                        continuation.resume(returning: Self.resizeImageIfNeeded(image))
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            }
            
            return result
        } else if let name = localImageName, let image = UIImage(named: name) {
            return Self.resizeImageIfNeeded(image)
        } else {
            return nil
        }
    }
}
