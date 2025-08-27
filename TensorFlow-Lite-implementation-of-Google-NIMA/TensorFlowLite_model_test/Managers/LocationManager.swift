import Foundation
import CoreLocation

actor LocationManager {
    static let shared = LocationManager()
    private init() {}
    
    private let geocoder = CLGeocoder()
    private var locationCache: [String: String] = [:]  // key: "lat,lon", value: location name
    
    func getLocationName(for location: CLLocation) async -> String {
        // Check cache first
        let cacheKey = "\(location.coordinate.latitude),\(location.coordinate.longitude)"
        if let cachedName = locationCache[cacheKey] {
            return cachedName
        }
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                var components: [String] = []
                if let country = placemark.country { components.append(country) }
                if let administrativeArea = placemark.administrativeArea { components.append(administrativeArea) }
                if let locality = placemark.locality { components.append(locality) }
                if let subLocality = placemark.subLocality { components.append(subLocality) }
                
                let locationName = components.joined(separator: " ")
                locationCache[cacheKey] = locationName
                return locationName
            }
        } catch {
            print("Geocoding error: \(error.localizedDescription)")
        }
        
        return "Unkown Location"
    }
    
    func clearCache() {
        locationCache.removeAll()
    }
}
