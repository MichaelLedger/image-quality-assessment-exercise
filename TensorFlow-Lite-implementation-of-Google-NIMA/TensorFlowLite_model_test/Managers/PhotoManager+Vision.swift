import UIKit
import Vision
import Photos

@available(iOS 18.0, *)
extension PhotoManager {
    func scoreByVision(_ asset: PHAsset) async -> Double? {
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
              let ciImage = CIImage(image: image) else {
            return nil
        }
        
        do {
            // Set up the calculate image aesthetics scores request
            let request = CalculateImageAestheticsScoresRequest()
            
            // Perform the request
            let observation = try await request.perform(on: ciImage)
            // Skip utility images
            if observation.isUtility {
                return nil
            }
            
            // Convert score from -1...1 to 1...10 to match NIMA scale
            let normalizedScore = ((observation.overallScore + 1) / 2) * 9 + 1
            return Double(normalizedScore)
        } catch {
            print("Vision analysis failed: \(error)")
        }
        
        return nil
    }
}
