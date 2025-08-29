import UIKit
import Vision
import Photos

extension PhotoManager {
    // MARK: - Label Detection
    
    func detectLabels(for asset: PHAsset) async -> String {
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
            return ""
        }
        
        // Create Vision request
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
            if let observations = request.results?.filter({ $0.confidence > 0.75 }).sorted(by: { $0.confidence > $1.confidence }) {
                let labels = observations.map { $0.identifier.lowercased() }
                return labels.joined(separator: "/")
            }
            return ""
        } catch {
            print("Vision request failed: \(error)")
            return ""
        }
    }
    
    // MARK: - Label Filtering
    
    func photoMeetsLabelCriteria(_ asset: PHAsset, requiredLabels: Set<String>, excludedLabels: Set<String>) async -> (Bool, String?) {
        let labels = await detectLabels(for: asset)
        if labels.isEmpty {
            return (false, nil)
        }
        
        let labelSet = Set(labels.split(separator: "/").map(String.init))
        
        // Check if any label is excluded
        if !excludedLabels.isEmpty {
            let hasExcludedLabel = !labelSet.isDisjoint(with: excludedLabels)
            if hasExcludedLabel {
                return (false, labels)
            }
        }
        
        // Check if the photo has at least one required label
        if !requiredLabels.isEmpty {
            let hasRequiredLabel = !labelSet.isDisjoint(with: requiredLabels)
            return (hasRequiredLabel, labels)
        }
        
        return (true, labels)
    }
    
    func photoMeetsLabelCriteria(_ label: String?, requiredLabels: Set<String>? = nil, excludedLabels: Set<String>? = nil) async -> Bool {
        guard let label = label?.lowercased(), !label.isEmpty else {
            return false
        }
        
        let labelSet = Set(label.split(separator: "/").map(String.init))
        
        let actorExcludedLabels = await PhotoManager.shared.excludedLabels
        
        // NOTE: exclude first!!! (e.g. document/screenshot/people)
        if excludedLabels == nil {
            // Check if any label is excluded
            if !actorExcludedLabels.isEmpty, !labelSet.isDisjoint(with: actorExcludedLabels) {
                return false
            }
        } else {
            // Check if any label is excluded
            if let excludedLabels, !excludedLabels.isEmpty, !labelSet.isDisjoint(with: excludedLabels) {
                return false
            }
        }
        
        if requiredLabels == nil {
            // Check if the photo has at least one required label
            let actorRequiredLabels = await PhotoManager.shared.requiredLabels
            if !actorRequiredLabels.isEmpty, !labelSet.isDisjoint(with: actorRequiredLabels) {
                return true
            }
        } else {
            // Check if the photo has at least one required label
            if let requiredLabels, !requiredLabels.isEmpty, !labelSet.isDisjoint(with: requiredLabels) {
                return true
            }
        }
        if (requiredLabels == nil || requiredLabels!.isEmpty) && (actorExcludedLabels.isEmpty) {
            return true
        } else {
            return false
        }
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
            let labels = await detectLabels(for: asset)
            let labelSet = Set(labels.split(separator: "/").map(String.init))
            for label in labelSet {
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
