import UIKit

extension UIImage {
    /// Resizes the image to ensure both width and height are at least the specified minimum dimension
    /// while maintaining the aspect ratio.
    /// - Parameter minDimension: The minimum dimension (width or height) that the resulting image should have
    /// - Returns: A new image that meets the minimum dimension requirement, or self if already large enough
    func resizedToMinimumDimension(_ minDimension: CGFloat) -> UIImage {
        // If image is already large enough, return as is
        if size.width >= minDimension && size.height >= minDimension {
            return self
        }
        
        // Calculate scale needed to make both dimensions >= minDimension
        let widthRatio = minDimension / size.width
        let heightRatio = minDimension / size.height
        let scale = max(widthRatio, heightRatio)
        let newSize = CGSize(
            width: size.width * scale,
            height: size.height * scale
        )
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage ?? self
    }
}
