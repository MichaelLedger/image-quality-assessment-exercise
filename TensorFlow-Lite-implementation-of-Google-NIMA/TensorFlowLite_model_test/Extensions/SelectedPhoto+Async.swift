import UIKit

extension SelectedPhoto {
    func loadImageAsync(targetSize: CGSize) async -> UIImage? {
        await withCheckedContinuation { continuation in
            loadImage(targetSize: targetSize) { image in
                continuation.resume(returning: image)
            }
        }
    }
}
