//
//  GoogleImageLabels.swift
//  MemoryDemo
//
//
import Foundation
import UIKit
import MLKitImageLabeling
import Vision
import MLKitVision

private enum Constants {

  static let detectionNoResultsMessage = "No results returned."
  static let failedToDetectObjectsMessage = "Failed to detect objects in image."
  static let labelConfidenceThreshold = 0.75
}

struct GoogleImageLabels {
    
    static func detectImageLabels(
        image: UIImage,
        threshold: Float = 0.75,
        completion: @escaping (PhotoLabels?) -> Void
    ) {
        let option = ImageLabelerOptions()
        option.confidenceThreshold = NSNumber(floatLiteral: Constants.labelConfidenceThreshold)
        let onDeviceLabeler = ImageLabeler.imageLabeler(options: option)
        
        let visionImage = VisionImage(image: image)
        visionImage.orientation = image.imageOrientation
        
        onDeviceLabeler.process(visionImage) { labels, error in
            guard error == nil,
                  let labels = labels,
                  !labels.isEmpty,
                  let label = labels.sorted(by: { $0.confidence > $1.confidence }).first else {
                // [START_EXCLUDE]
                completion(nil)
                // [END_EXCLUDE]
                return
            }
            let index = label.index
            if let photoLabel = PhotoLabels(rawValue: index),
               label.confidence > threshold {
                debugPrint("\(label.text)====\(label.confidence)")
                completion(photoLabel)
            } else {
                completion(nil)
            } 
        }
        // [END detect_label]
    }

    static func detectImageLabelsSync(image: UIImage) -> PhotoLabels? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: PhotoLabels?
        
        detectImageLabels(image: image) { labels in
            result = labels
            semaphore.signal()
        }
        
        semaphore.wait()
        return result
    }
}
