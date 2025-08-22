import Photos
import CoreLocation

struct LocationGroup {
    let id: String
    let assets: [PHAsset]
    let location: CLLocation
    
    init(assets: [PHAsset], location: CLLocation) {
        self.id = UUID().uuidString
        self.assets = assets
        self.location = location
    }
    
    var previewAssets: [PHAsset] {
        Array(assets.prefix(5))
    }
} 
