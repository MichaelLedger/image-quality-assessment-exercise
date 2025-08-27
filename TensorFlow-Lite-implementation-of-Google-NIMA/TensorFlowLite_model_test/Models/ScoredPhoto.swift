import UIKit
import Photos
import CoreLocation

struct ScoredPhoto {
    let assetIdentifier: String?
    let localImageName: String?
    let modificationDate: Date?
    let score: Double
    let label: String?
    private(set) var locationName: String?
    private(set) var location: CLLocation?
    var image: UIImage? { localImageName.flatMap(UIImage.init) }
    
    init(assetIdentifier: String?, localImageName: String?, modificationDate: Date?, score: Double, label: String? = nil, location: CLLocation? = nil, locationName: String? = nil) {
        self.assetIdentifier = assetIdentifier
        self.localImageName = localImageName
        self.modificationDate = modificationDate
        self.score = score
        self.label = label
        self.location = location
        self.locationName = locationName
    }
    
    mutating func updateLocationName(_ name: String) {
        self.locationName = name
    }
    
    mutating func updateLocation(_ location: CLLocation) {
        self.location = location
    }
    
    func loadAssetImage(targetSize: CGSize = .zero, completion: @escaping (UIImage?) -> Void) {
        guard let identifier = assetIdentifier else {
            completion(image)
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
}
