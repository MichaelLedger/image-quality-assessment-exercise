import UIKit
import Photos

class CustomImageView: UIImageView {
    var assetID: String?
    
    func fetchImageAsset(_ asset: PHAsset,
                         targetSize size: CGSize,
                         contentMode: PHImageContentMode = .aspectFill,
                         options: PHImageRequestOptions? = nil,
                         photoId: String? = nil) {
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: size.width * 3, height: size.height * 3),
            contentMode: .aspectFit,
            options: options
        ) { [weak self] image, _ in
            DispatchQueue.main.async {[weak self] in
                guard let self = self else {return}
                if self.assetID == photoId {
                    self.image = image
                }
            }
        }
    }
} 