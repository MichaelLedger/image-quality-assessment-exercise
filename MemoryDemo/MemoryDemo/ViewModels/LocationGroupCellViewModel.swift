import Photos
import Combine
import CoreLocation

class LocationGroupCellViewModel: ObservableObject {
    let locationGroup: LocationGroup
    @Published private(set) var recommendedAssets: Set<PHAsset> = []
    @Published private(set) var isProcessingComplete: Bool = false
    
    init(locationGroup: LocationGroup) {
        self.locationGroup = locationGroup
        checkProcessingStatus()
    }
    
    private func checkProcessingStatus() {
        isProcessingComplete = PhotoRecommendManager.shared.isProcessingComplete(for: locationGroup.id)
        if isProcessingComplete {
            if let recommended = PhotoRecommendManager.shared.getRecommendedAssets(for: locationGroup.id) {
                recommendedAssets = recommended
            }
        }
    }
    
    func updateRecommendedAssets(_ assets: Set<PHAsset>) {
        recommendedAssets = assets
        isProcessingComplete = true
    }
    
    var locationText: String = ""
} 
