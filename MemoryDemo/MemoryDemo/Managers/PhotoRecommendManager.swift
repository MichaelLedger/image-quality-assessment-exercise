import Photos
import Vision
import UIKit
import MLKitImageLabeling
import Combine

class LocationGroupProcessOperation: Operation, @unchecked Sendable {
    private let locationGroup: LocationGroup
    private let threshold: Float
    private let imageManager: PHImageManager
    private let imageRequestOption: PHImageRequestOptions
    private let featureGroup = DispatchGroup()
    private let processingQueue = DispatchQueue(label: "com.memorydemo.processing", qos: .userInitiated)
    private let completion: (String, Set<PHAsset>) -> Void
    
    init(locationGroup: LocationGroup,
         threshold: Float = 0.35,
         imageManager: PHImageManager = .default(),
         imageRequestOption: PHImageRequestOptions,
         completion: @escaping (String, Set<PHAsset>) -> Void) {
        self.locationGroup = locationGroup
        self.threshold = threshold
        self.imageManager = imageManager
        self.imageRequestOption = imageRequestOption
        self.completion = completion
        super.init()
    }
    
    override func main() {
        guard !isCancelled else { return }
        
        debugPrint("starttime===== \(Date())")
        
        // 局部变量，不需要加锁
        var featureMap: [PHAsset: VNFeaturePrintObservation] = [:]
        var labelsMap: [PHAsset: PhotoLabels] = [:]
        
        // 处理所有资源
        for asset in locationGroup.assets {
            guard !isCancelled else { return }
            
            featureGroup.enter()
            
            
            imageManager.requestImage(for: asset,
                                   targetSize: CGSize(width: 400, height: 400),
                                   contentMode: .aspectFit,
                                   options: imageRequestOption) { [weak self] image, info in
                guard let self = self else {
                    self?.featureGroup.leave()
                    return
                }
                
                guard !self.isCancelled else {
                    self.featureGroup.leave()
                    return
                }
                
                // 确保图片加载完成且没有降级
                guard let image,
                      let cgImage = image.cgImage,
                      info?[PHImageResultIsDegradedKey] as? Bool == false else {
                    if info?[PHImageCancelledKey] as? Bool == true {
                        self.featureGroup.leave()
                    }
                    return
                }
                
                // 在子线程中处理相似度和标签
                self.processingQueue.async {
                    // 处理相似度
                    let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                    let request = VNGenerateImageFeaturePrintRequest()
                    
                    do {
                        try requestHandler.perform([request])
                        if let result = request.results?.first as? VNFeaturePrintObservation {
                            featureMap[asset] = result
                        }
                    } catch {
                        print("Error generating feature print: \(error)")
                    }
                    
                    // 使用同步版本处理标签
                    GoogleImageLabels.detectImageLabels(image: image) { label in
                        if let label {
                            labelsMap[asset] = label
                        }
                        self.featureGroup.leave()
                    }
//                    if let label = GoogleImageLabels.detectImageLabelsSync(image: image) {
//                        
//                    }
                    
                }
            }
        }
        
        featureGroup.wait()
        
        guard !isCancelled else { return }
        
        var removedAssets = Set<PHAsset>()
        var uniqueAssets = Set<PHAsset>()
        
        // 处理去重逻辑
        for (i, asset1) in locationGroup.assets.enumerated() {
            guard !isCancelled else { return }
            
            guard !removedAssets.contains(asset1),
                  let fp1 = featureMap[asset1] else { continue }
            var isDuplicate = false
            
            for j in 0..<i {
                let asset2 = locationGroup.assets[j]
                guard !removedAssets.contains(asset2),
                      let fp2 = featureMap[asset2] else { continue }
                var distance: Float = 0
                do {
                    try fp1.computeDistance(&distance, to: fp2)
                    distance = ceil(distance * 100) / 100.0
                    if distance < threshold {
                        isDuplicate = true
                        break
                    }
                } catch {
                    print("Error computing distance: \(error)")
                }
            }
            
            let label = labelsMap[asset1]
            if label != nil,
               isDuplicate == false,
               !printableThemes.contains(label!) {
                isDuplicate = true
            }
            
            if !isDuplicate,
               label != nil {
                uniqueAssets.insert(asset1)
            } else {
                removedAssets.insert(asset1)
            }
        }
        
        debugPrint("endtime===== \(Date())")
        
        guard !isCancelled else { return }
        
        completion(locationGroup.id, uniqueAssets)
    }
}

class PhotoRecommendManager {
    static let shared = PhotoRecommendManager()
    
    private var recommendationCache: [String: Set<PHAsset>] = [:]
    private var processingStatus: [String: Bool] = [:]
    private var recommendationSubject = PassthroughSubject<(String, Set<PHAsset>), Never>()
    
    private let concurrentQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 10
        return queue
    }()
    
    private let cacheLock = NSRecursiveLock()
    private let statusLock = NSRecursiveLock()
    
    lazy var imageRequestOption: PHImageRequestOptions = {
        let requestOptions = PHImageRequestOptions()
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.isNetworkAccessAllowed = true
        requestOptions.isSynchronous = false
        return requestOptions
    }()
    
    var recommendationPublisher: AnyPublisher<(String, Set<PHAsset>), Never> {
        recommendationSubject.eraseToAnyPublisher()
    }
    
    private init() {}
    
    func processLocationGroup(_ locationGroup: LocationGroup, threshold: Float = 0.35) {
        let groupId = locationGroup.id
        
        statusLock.lock()
        if processingStatus[groupId] == true {
            statusLock.unlock()
            return
        }
        processingStatus[groupId] = false
        statusLock.unlock()
        
        let operation = LocationGroupProcessOperation(
            locationGroup: locationGroup,
            threshold: threshold,
            imageRequestOption: imageRequestOption
        ) { [weak self] groupId, uniqueAssets in
            guard let self = self else { return }
            
            self.cacheLock.lock()
            self.recommendationCache[groupId] = uniqueAssets
            self.cacheLock.unlock()
            
            self.statusLock.lock()
            self.processingStatus[groupId] = true
            self.statusLock.unlock()
            
            self.recommendationSubject.send((groupId, uniqueAssets))
        }
        
        concurrentQueue.addOperation(operation)
    }
    
    func cancelAllProcessing() {
        concurrentQueue.cancelAllOperations()
    }
    
    func getRecommendedAssets(for groupId: String) -> Set<PHAsset>? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return recommendationCache[groupId]
    }
    
    func isProcessingComplete(for groupId: String) -> Bool {
        statusLock.lock()
        defer { statusLock.unlock() }
        return processingStatus[groupId] ?? false
    }
} 
