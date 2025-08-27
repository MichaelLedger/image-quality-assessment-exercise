import UIKit
import Photos
import CoreLocation

struct SelectedPhoto {
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
}
