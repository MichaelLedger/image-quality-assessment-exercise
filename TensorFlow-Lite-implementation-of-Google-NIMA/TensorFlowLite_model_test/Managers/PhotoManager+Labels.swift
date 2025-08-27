import UIKit
import Vision
import Photos

extension PhotoManager {
    // MARK: - Label Detection
    
    func detectLabels(for asset: PHAsset) async -> [VNClassificationObservation] {
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
            return []
        }
        
        // Create Vision request
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
            return request.results?.filter { $0.confidence > 0.75 } ?? []
        } catch {
            print("Vision request failed: \(error)")
            return []
        }
    }
    
    // MARK: - Label Filtering
    
    func photoMeetsLabelCriteria(_ asset: PHAsset, requiredLabels: Set<String>, excludedLabels: Set<String>) async -> (Bool, String?) {
        let observations = await detectLabels(for: asset)
        
        // Get the top label
        guard let topLabel = observations.first?.identifier.lowercased() else {
            return (false, nil)
        }
        
        // Check if the label is excluded
        if !excludedLabels.isEmpty, excludedLabels.contains(topLabel) {
            return (false, topLabel)
        }
        
        // Check if the photo has at least one required label
        if !requiredLabels.isEmpty {
            let hasRequiredLabel = observations.contains { observation in
                requiredLabels.contains(observation.identifier.lowercased())
            }
            return (hasRequiredLabel, topLabel)
        }
        
        return (true, topLabel)
    }
    
    func photoMeetsLabelCriteria(_ label: String?, requiredLabels: Set<String>? = nil, excludedLabels: Set<String>? = nil) -> (Bool, String?) {
        guard let label = label?.lowercased() else {
            return (false, nil)
        }
        // Check if the label is excluded
        if let excludedLabels, !excludedLabels.isEmpty, excludedLabels.contains(label) {
            return (false, label)
        }
        // Check if the photo has at least one required label
        if let requiredLabels, !requiredLabels.isEmpty, requiredLabels.contains(label) {
            return (true, label)
        }
        return (true, label)
    }
    
    // MARK: - Label Cache Management
    
    func updateLabelCache(for asset: PHAsset, with label: String) {
        labelCache[asset.localIdentifier] = label
    }
    
    func clearLabelCache() {
        labelCache.removeAll()
    }
    
    // MARK: - Label Statistics
    
    func getLabelStatistics(for photos: [PHAsset]) async -> [String: Int] {
        var labelCounts: [String: Int] = [:]
        
        for asset in photos {
            let observations = await detectLabels(for: asset)
            for observation in observations {
                let label = observation.identifier.lowercased()
                labelCounts[label, default: 0] += 1
            }
        }
        
        return labelCounts
    }
    
    // MARK: - Label Suggestions
    
    func suggestLabels(for photos: [PHAsset], limit: Int = 10) async -> [String] {
        let labelCounts = await getLabelStatistics(for: photos)
        
        // Sort labels by frequency and return top N
        return labelCounts.sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0.key }
    }
}
