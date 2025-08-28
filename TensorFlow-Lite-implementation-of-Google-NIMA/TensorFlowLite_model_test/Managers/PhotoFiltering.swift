import UIKit
import Vision
import Photos

extension PhotoManager {
    // MARK: - Feature Print Generation
    
    func generateFeaturePrint(for image: UIImage) async throws -> VNFeaturePrintObservation? {
        guard let cgImage = image.cgImage else { return nil }
        
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])
        return request.results?.first as? VNFeaturePrintObservation
    }
    
    // MARK: - Similarity Check
    
    func isSimilarToExistingPhotos(_ asset: PHAsset) async -> Bool {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        
        // Convert PHImageManager callback to async
        let image = await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 512, height: 512),
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
        
        guard let image = image else { return false }
        
        do {
            var isSimilar = false
            let distanceTolerance = self.distanceTolerance()
            let distanceConfidenceThreshold = self.distanceConfidenceThreshold()
            
            if let newFeaturePrint = try await generateFeaturePrint(for: image) {
                // Check against cached feature prints
                try featurePrintCache.forEach { (key, feature) in
                    var distance: Float = 0
                    try newFeaturePrint.computeDistance(&distance, to: feature)
                    
                    // If distance is less than threshold and confidence is high enough, consider it similar
                    if newFeaturePrint.confidence >= distanceConfidenceThreshold, distance < distanceTolerance {
                        print("Found similar photo with distance: \(distance), tolerance: \(distanceTolerance), confidence: \(newFeaturePrint.confidence)")
                        isSimilar = true
                    }
                }
                
                // Cache the new feature print if not similar
                if !isSimilar {
                    setCachedFeaturePrint(newFeaturePrint, for: asset.localIdentifier)
                }
            }
            return isSimilar
        } catch {
            print("Error generating feature print: \(error)")
            return false
        }
    }
    
    // MARK: - Helper Methods
    
    private func distanceConfidenceThreshold() -> Float {
        return 0.75
    }
    
    private func distanceTolerance() -> Float {
        // On iOS 17, the distance between two observations is always less than 2.0
        // On iOS 16, the distance can vary a lot; typical values range between 0.0 and 40.0
        let tolerance = 0.2 // Adjust this value to control similarity sensitivity
        if #available(iOS 17.0, *) {
            return Float(2.0 * tolerance)
        } else {
            return Float(40.0 * tolerance)
        }
    }
    
    // MARK: - Label Detection
    
    func detectImageLabel(for asset: PHAsset) async -> String? {
        // Check cache first
        if let cachedLabel = getCachedLabel(for: asset.localIdentifier) {
            return cachedLabel
        }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        
        // Convert PHImageManager callback to async
        let image = await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 512, height: 512),
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
        
        guard let image = image,
              let cgImage = image.cgImage else {
            return nil
        }
        
        // Create Vision request
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
            
            // Get all observations with confidence > 0.75 and join their identifiers
            if let observations = request.results?.filter({ $0.confidence > 0.75 }).sorted(by: { $0.confidence > $1.confidence }) {
                let labels = observations.map { $0.identifier.lowercased() }
                let label = labels.joined(separator: "/")
                setCachedLabel(label, for: asset.localIdentifier)
                return label
            }
        } catch {
            print("Vision request failed: \(error)")
        }
        
        return nil
    }
    
    // MARK: - Photo Filtering
    
    func filterPhotos(_ photos: [PHAsset], labelCache: inout [String: String]) async -> [PHAsset] {
        var filteredPhotos: [PHAsset] = []
        
        featurePrintCache.removeAll()
        
        for photo in photos {
            // Check for duplicates by asset identifier
            if filteredPhotos.contains(where: { $0.localIdentifier == photo.localIdentifier }) {
                continue
            }
            
            // Check for similar photos
            if await isSimilarToExistingPhotos(photo) {
                continue
            }
            
            // Add the photo if it passes all filters
            filteredPhotos.append(photo)
        }
        
        return filteredPhotos
    }
}
