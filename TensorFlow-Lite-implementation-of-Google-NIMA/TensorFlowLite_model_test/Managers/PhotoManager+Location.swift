import UIKit
import Photos
import CoreLocation
import Vision

extension PhotoManager {
    // MARK: - Location Album Fetching
    
    func fetchLocationAlbums(fetchLimit: Int = 1000) async throws -> [ScoredPhoto] {
        // Request photo library authorization
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized else {
            return []
        }
        
        // Fetch photos with location data
        let fetchOptions = PHFetchOptions()
        fetchOptions.fetchLimit = fetchLimit
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        var photos: [PHAsset] = []
        assets.enumerateObjects { asset, _, _ in
            if asset.location != nil {
                photos.append(asset)
            }
        }
        
        // Group photos by location
        let groupedPhotos = Dictionary(grouping: photos) { photo in
            self.locationKey(for: photo.location)
        }
        
        var scoredPhotos: [ScoredPhoto] = []
        
        // Process each location group
        for (_, locationPhotos) in groupedPhotos {
            // Filter similar photos within the location group
            var labelCache: [String : String] = [:]
            let filteredPhotos = await self.filterPhotos(locationPhotos, labelCache: &labelCache)
            self.updateLabelCacheWithDictionary(labelCache)
            
            // Process each filtered photo
            for photo in filteredPhotos {
                // Get label
                let label = await self.detectImageLabel(for: photo)
                
                let photoMeetsLabelCriteria = await PhotoManager.shared.photoMeetsLabelCriteria(label)
                
                // filter by label criteria
                if !photoMeetsLabelCriteria {
                    continue
                }
                
                // Get Location Name
                var locationName: String? = nil
                if let photoLocation = photo.location {
                    locationName = await LocationManager.shared.getLocationName(for: photoLocation)
                }
                
                // Score the photo using Vision
                if #available(iOS 18.0, *),
                   let score = await self.scoreByVision(photo) {
                    let scoredPhoto = ScoredPhoto(
                        assetIdentifier: photo.localIdentifier,
                        localImageName: nil,
                        modificationDate: photo.modificationDate,
                        score: score,
                        label: label,
                        location: photo.location,
                        locationName: locationName
                    )
                    scoredPhotos.append(scoredPhoto)
                }
            }
        }
        
        // Sort by score (highest first)
        return scoredPhotos.sorted { $0.score > $1.score }
    }
    
    // MARK: - Location Helpers
    
    private nonisolated func locationKey(for location: CLLocation?) -> String {
        guard let location = location else { return "Unknown Location" }
        
        // Round coordinates to group nearby locations (approximately 1km accuracy)
        let roundedLat = round(location.coordinate.latitude * 100) / 100
        let roundedLon = round(location.coordinate.longitude * 100) / 100
        
        return "\(roundedLat),\(roundedLon)"
    }
    
    private func getLocationName(for location: CLLocation, completion: @escaping (String) -> Void) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let error = error {
                print("Geocoding error: \(error)")
                completion("Unknown Location")
                return
            }
            
            guard let placemark = placemarks?.first else {
                completion("Unknown Location")
                return
            }
            
            var locationName = ""
            
            // Build location name from most specific to least specific
            if let name = placemark.name {
                locationName = name
            } else if let thoroughfare = placemark.thoroughfare {
                locationName = thoroughfare
            } else if let locality = placemark.locality {
                locationName = locality
            } else if let area = placemark.administrativeArea {
                locationName = area
            } else if let country = placemark.country {
                locationName = country
            } else {
                locationName = "Unknown Location"
            }
            
            completion(locationName)
        }
    }
}
