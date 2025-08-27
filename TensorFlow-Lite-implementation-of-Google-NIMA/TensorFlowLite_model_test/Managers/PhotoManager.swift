import UIKit
import Photos
import Vision
import Firebase
import FirebaseMLCommon

// UserDefaults keys
public enum PreferenceKeys {
    static let maxPhotoCount = "maxPhotoCount"
    static let requiredLabels = "requiredLabels"
    static let excludedLabels = "excludedLabels"
}

actor PhotoManager {
    
    static let shared = PhotoManager()
    
    // Maximum number of recent photos to analyze (0 means all)
    public var maxPhotoCount: Int {
        get {
            return UserDefaults.standard.integer(forKey: PreferenceKeys.maxPhotoCount)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: PreferenceKeys.maxPhotoCount)
            UserDefaults.standard.synchronize()
        }
    }
    
    public let defaultLabels: Set<String> = ["people", "team", "bonfire", "park", "graduation", "ferrisWheel", "wetsuit", "brig", "competition", "safari", "stadium",
                                             "smile", "surfboard", "sunset", "sky", "interaction", "person", "windsurfing", "swimwear", "camping", "playground",
                                             "concert", "prom", "bar", "nightclub", "christmas", "jungle", "skyline", "skateboarder", "dance", "santaClaus", "thanksgiving", "sledding", "vacation", "pitch", "monument", "speedboat", "food", "forest", "waterfall",
                                             "desert", "grandparent", "love", "motorcycle", "leisure", "lake", "moon", "marriage", "party", "plant", "pet", "skateboard",
                                             "rugby", "river", "star", "sports", "swimming", "superman", "superhero", "skiing", "skyscraper", "volcano", "tattoo",
                                             "ranch", "fishing", "mountain", "singer", "carnival", "snowboarding", "beach", "rainbow", "garden", "flower", "cathedral",
                                             "castle", "aurora", "racing", "fun", "cake", "fireworks", "prairie", "sailboat", "supper", "waterfall", "lunch", "baby",
                                             "canyon", "bride", "joker", "selfie", "storm", "skin"]
    
    //test
    /*
     let defaultLabels: Set<String> = ["team", "bonfire", "park", "graduation", "ferrisWheel", "wetsuit", "brig", "competition", "safari", "stadium",
     "smile", "surfboard", "sunset", "sky", "interaction", "person", "windsurfing", "swimwear", "camping", "playground",
     "concert", "prom", "bar", "nightclub", "christmas", "jungle", "skyline", "skateboarder", "dance", "santaClaus", "thanksgiving", "sledding", "vacation", "pitch", "monument", "speedboat", "food", "forest", "waterfall",
     "desert", "grandparent", "love", "motorcycle", "leisure", "lake", "moon", "marriage", "party", "plant", "pet", "skateboard",
     "rugby", "river", "star", "sports", "swimming", "superman", "superhero", "skiing", "skyscraper", "volcano", "tattoo",
     "ranch", "fishing", "mountain", "singer", "carnival", "snowboarding", "beach", "rainbow", "garden", "flower", "cathedral",
     "castle", "aurora", "racing", "fun", "cake", "fireworks", "prairie", "sailboat", "supper", "waterfall", "lunch", "baby",
     "canyon", "bride", "joker", "selfie", "storm", "skin", "outdoor", "document", "animal", "recreation"]
     */
    
    public let defaultExcludedLabels: Set<String> =  ["document"]
    
    public var excludedLabels: Set<String> {
        get {
            if let data = UserDefaults.standard.data(forKey: PreferenceKeys.excludedLabels),
               let labels = try? JSONDecoder().decode(Set<String>.self, from: data) {
                return labels
            }
            return defaultExcludedLabels
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: PreferenceKeys.excludedLabels)
                UserDefaults.standard.synchronize()
            }
        }
    }
    
    public var requiredLabels: Set<String> {
        get {
            if let data = UserDefaults.standard.data(forKey: PreferenceKeys.requiredLabels),
               let labels = try? JSONDecoder().decode(Set<String>.self, from: data) {
                return labels
            }
            return defaultLabels
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: PreferenceKeys.requiredLabels)
                UserDefaults.standard.synchronize()
            }
        }
    }
    
    private init() {}
    
    // MARK: - Reset to default labels
    
    public func resetToDefaultLabels() {
        requiredLabels = defaultLabels
        excludedLabels = defaultExcludedLabels
    }
    
    // MARK: - Authorization
    
    func checkPhotoLibraryAuthorization() async -> Bool {
        let status = await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        
        switch status {
        case .authorized, .limited:
            return true
        default:
            return false
        }
    }
    
    // MARK: - Photo Fetching
    
    private func fetchUserLibraryAlbum() -> PHAssetCollection? {
        let smartAlbumCollections = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum,
            subtype: .any,
            options: nil
        )
        var smartAlbumRecentlyAdded: PHAssetCollection?
        smartAlbumCollections.enumerateObjects { collection, start, stop in
            if collection.assetCollectionSubtype == .smartAlbumUserLibrary {
                smartAlbumRecentlyAdded = collection
                stop.pointee = true
            }
        }
        return smartAlbumRecentlyAdded
    }
    
    private func createFetchOptions(maxPhotoCount: Int) -> PHFetchOptions {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        if maxPhotoCount > 0 {
            fetchOptions.fetchLimit = maxPhotoCount
        }
        return fetchOptions
    }
    
    func fetchRecentPhotos(maxPhotoCount: Int = 500) async -> [SelectedPhoto] {
        // Clear caches
        clearCaches()
        
        let auth = await checkPhotoLibraryAuthorization()
        guard auth else {
            return []
        }
        
        // Get the album and fetch options
        guard let smartAlbumRecentlyAdded = fetchUserLibraryAlbum() else {
            return []
        }
        let fetchOptions = createFetchOptions(maxPhotoCount: maxPhotoCount)
        
        // Fetch the most recent photos
        let assets = PHAsset.fetchAssets(in: smartAlbumRecentlyAdded, options: fetchOptions)
            
        return await processPhotosInParallel(assets: assets)
    }
    
    private func processPhotosInParallel(assets: PHFetchResult<PHAsset>) async -> [SelectedPhoto] {
        var processedIdentifiers = Set<String>()
        let identifiersLock = NSLock()
        var counter = 0
        
        // Convert PHFetchResult to Array to avoid closure capture issues
        var assetsArray: [PHAsset] = []
        assets.enumerateObjects(options: .reverse) { asset, _, _ in
            assetsArray.append(asset)
        }
        
        // Process in smaller batches with timeout
        let batchSize = 20 // Reduced batch size
        var allPhotos: [SelectedPhoto] = []
        
        // Process each batch sequentially
        for batch in stride(from: 0, to: assetsArray.count, by: batchSize) {
            let end = min(batch + batchSize, assetsArray.count)
            let batchAssets = Array(assetsArray[batch..<end])
            let batchNumber = batch/batchSize + 1
            
            print("Starting batch \(batchNumber)...")
            
            // Process photos in this batch sequentially
            for (index, asset) in batchAssets.enumerated() {
                print("Batch \(batchNumber): Processing photo \(index + 1)/\(batchAssets.count)")
                
                if let photo = await processPhoto(
                    asset: asset,
                    counter: &counter,
                    totalCount: assets.count,
                    processedIdentifiers: &processedIdentifiers,
                    identifiersLock: identifiersLock
                ) {
                    allPhotos.append(photo)
                    print("Batch \(batchNumber): Successfully processed photo \(index + 1)/\(batchAssets.count)")
                }
            }
            
            print("Batch \(batchNumber) completed. Processed \(end) of \(assetsArray.count) photos. Successfully processed: \(allPhotos.count)")
        }
        
        print("All photos processed. Total selected: \(allPhotos.count)")
        return allPhotos
    }
    
    private func processPhoto(
        asset: PHAsset,
        counter: inout Int,
        totalCount: Int,
        processedIdentifiers: inout Set<String>,
        identifiersLock: NSLock
    ) async -> SelectedPhoto? {
        counter += 1
        print("Processing photo \(counter)/\(totalCount): \(asset.localIdentifier)")
        
        // Check for duplicates
        identifiersLock.lock()
        let isDuplicate = processedIdentifiers.contains(asset.localIdentifier)
        processedIdentifiers.insert(asset.localIdentifier)
        identifiersLock.unlock()
        
        if isDuplicate {
            print("Duplicate photo skipped: \(asset.localIdentifier)")
            return nil
        }
        
        // Check for similar photos
        let isSimilar = await isSimilarToExistingPhotos(asset)
        if isSimilar {
            print("Similar photo skipped: \(asset.localIdentifier)")
            return nil
        }
        
        // Check label criteria
        let label = await detectImageLabel(for: asset)
        let meetsLabelCriteria = await photoMeetsLabelCriteria(label).0
        if !meetsLabelCriteria {
            print("Photo excluded by label criteria: \(asset.localIdentifier) with label \(label ?? "nil")")
            return nil
        }
        
        // Create photo with location
        var selectedPhoto = SelectedPhoto.fromAsset(asset)
        selectedPhoto.updateLabel(label)
        
        if let location = asset.location {
            let locationName = await LocationManager.shared.getLocationName(for: location)
            selectedPhoto.updateLocation(location)
            selectedPhoto.updateLocationName(locationName)
        }
        
        print("Photo selected: \(asset.localIdentifier) with label \(label ?? "nil")")
        return selectedPhoto
    }
    
    public var featurePrintCache: [String: VNFeaturePrintObservation] = [:]
    public var labelCache: [String: String] = [:]
    
    // MARK: - Cache Management
    
    func getCachedLabel(for identifier: String) -> String? {
        return labelCache[identifier]
    }
    
    func setCachedLabel(_ label: String, for identifier: String) {
        labelCache[identifier] = label
    }
    
    func getCachedFeaturePrint(for identifier: String) -> VNFeaturePrintObservation? {
        return featurePrintCache[identifier]
    }
    
    func setCachedFeaturePrint(_ featurePrint: VNFeaturePrintObservation, for identifier: String) {
        featurePrintCache[identifier] = featurePrint
    }
    
    func clearCaches() {
        featurePrintCache.removeAll()
        labelCache.removeAll()
    }
    
    // MARK: - Photo Fetching
    
    func fetchMomentsAlbums(fetchLimit: Int = 1000, completion: @escaping ([ScoredPhoto]) -> Void) {
        // Request photo library access
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            guard let self = self, status == .authorized else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            Task {
                // Fetch moments collections
                let result = PHAssetCollection.fetchMoments(with: nil)
                var locationGroups: [[PHAsset]] = []
                //let groupLock = NSLock()
                let fetchOptions = PHFetchOptions()
                fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
                
                // Collect moments with locations first
                var momentsWithLocation: [PHAssetCollection] = []
                result.enumerateObjects { collection, _, _ in
                    if collection.approximateLocation != nil {
                        momentsWithLocation.append(collection)
                    }
                }
                
                // Process moments concurrently
                await withTaskGroup(of: [PHAsset].self) { group in
                    // Add tasks for each moment
                    for collection in momentsWithLocation {
                        group.addTask {
                            let assetsInMoment = PHAsset.fetchAssets(in: collection, options: fetchOptions)
                            var momentAssets: [PHAsset] = []
                            
                            assetsInMoment.enumerateObjects { asset, _, _ in
                                momentAssets.append(asset)
                            }
                            
                            return momentAssets
                        }
                    }
                    
                    // Collect results
                    for await momentAssets in group {
                        if !momentAssets.isEmpty {
                            //groupLock.lock()
                            locationGroups.append(momentAssets)
                            //groupLock.unlock()
                        }
                    }
                }
                
                // Flatten and limit photos while preserving groups
                var photos: [PHAsset] = []
                for group in locationGroups {
                    if photos.count >= fetchLimit { break }
                    photos.append(contentsOf: group.prefix(fetchLimit - photos.count))
                }
                
                // Group photos by moment
                let groupedPhotos = Dictionary(grouping: photos) { photo in
                    var momentKey = photo.creationDate?.description ?? "Unknown"
                    
                    // Find the moment that contains this photo
                    result.enumerateObjects { moment, _, stop in
                        let assets = PHAsset.fetchAssets(in: moment, options: nil)
                        if assets.contains(photo) {
                            momentKey = "\(moment.localizedTitle ?? "") - \(moment.approximateLocation?.coordinate.latitude ?? 0),\(moment.approximateLocation?.coordinate.longitude ?? 0)"
                            stop.pointee = true
                        }
                    }
                    
                    return momentKey
                }
                
                var scoredPhotos: [ScoredPhoto] = []
                
                // Process each date group
                for (_, datePhotos) in groupedPhotos {
                    // Filter similar photos within the group
                    var labelCache: [String: String] = [:]
                    let filteredPhotos = await self.filterPhotos(datePhotos, labelCache: &labelCache)
                    self.labelCache = labelCache
                    
                    // Process each filtered photo
                    for photo in filteredPhotos {
                        // Get label
                        let label = await self.detectImageLabel(for: photo)
                        
                        // Score the photo using Vision
                        if #available(iOS 18.0, *),
                           let score = await self.scoreByVision(photo) {
                            // Get location name if available
                            var locationName: String? = nil
                            if let location = photo.location {
                                locationName = await LocationManager.shared.getLocationName(for: location)
                            }
                            
                            let scoredPhoto = ScoredPhoto(
                                assetIdentifier: photo.localIdentifier,
                                localImageName: nil,
                                modificationDate: photo.modificationDate,
                                score: score,
                                label: label,
                                location: photo.location,
                                locationName: locationName
                            )
                            scoredPhotos.append(scoredPhoto)
                        }
                    }
                }
                
                // Sort by score (highest first)
                let sortedPhotos = scoredPhotos.sorted { $0.score > $1.score }
                
                // Return on main thread
                DispatchQueue.main.async {
                    completion(sortedPhotos)
                }
            }
        }
    }
    
    // MARK: - Photo Scoring
    internal func scorePhoto(_ asset: PHAsset) async -> Double? {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        
        // Convert PHImageManager callback to async
        let original = await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 224, height: 224), // Size required by NIMA model
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
        
        guard let originalImg = original,
              let _ = originalImg.cgImage else {
            return nil
        }
        let image = PhotoManager.resizeImageIfNeeded(originalImg)
        guard let cgImage = image.cgImage, cgImage.width >= 224, cgImage.height >= 224 else {
            return nil
        }
        
        // Create context for image processing
        guard let context = CGContext(
            data: nil,
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: 8,
            bytesPerRow: cgImage.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else { return nil }
        
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        guard let imageData = context.data else { return nil }
        
        // Prepare input data for the model
        let inputs = ModelInputs()
        var inputData = Data()
        
        for row in 0..<224 {
            for col in 0..<224 {
                let offset = 4 * (col * context.width + row)
                let red = imageData.load(fromByteOffset: offset+1, as: UInt8.self)
                let green = imageData.load(fromByteOffset: offset+2, as: UInt8.self)
                let blue = imageData.load(fromByteOffset: offset+3, as: UInt8.self)
                
                // Normalize values to [0.0, 1.0]
                var normalizedRed = Float32(red) / 255.0
                var normalizedGreen = Float32(green) / 255.0
                var normalizedBlue = Float32(blue) / 255.0
                
                let elementSize = MemoryLayout.size(ofValue: normalizedRed)
                var bytes = [UInt8](repeating: 0, count: elementSize)
                
                memcpy(&bytes, &normalizedRed, elementSize)
                inputData.append(&bytes, count: elementSize)
                memcpy(&bytes, &normalizedGreen, elementSize)
                inputData.append(&bytes, count: elementSize)
                memcpy(&bytes, &normalizedBlue, elementSize)
                inputData.append(&bytes, count: elementSize)
            }
        }
        
        do {
            try inputs.addInput(inputData)
        } catch {
            print("Failed to add input: \(error)")
            return nil
        }
        
        // Create model options and interpreter
        let aestheticOptions = ModelOptions(
            remoteModelName: "aesthetic_model",
            localModelName: "aesthetic_model"
        )
        let technicalOptions = ModelOptions(
            remoteModelName: "technical_model",
            localModelName: "technical_model"
        )
        
        let aestheticInterpreter = ModelInterpreter.modelInterpreter(options: aestheticOptions)
        let technicalInterpreter = ModelInterpreter.modelInterpreter(options: technicalOptions)
        
        // Set up I/O options
        let ioOptions = ModelInputOutputOptions()
        do {
            try ioOptions.setInputFormat(index: 0, type: .float32, dimensions: [1, 224, 224, 3])
            try ioOptions.setOutputFormat(index: 0, type: .float32, dimensions: [1, 10])
        } catch {
            print("Failed to set I/O options: \(error)")
            return nil
        }
        
        // Run models and get scores
        let aestheticScore = await withCheckedContinuation { continuation in
            aestheticInterpreter.run(inputs: inputs, options: ioOptions) { outputs, error in
                var score = 0.0
                if error == nil,
                   let outputs = outputs,
                   let output = try? outputs.output(index: 0) as? [[NSNumber]],
                   let probabilities = output.first {
                    for (index, value) in probabilities.enumerated() {
                        score += Double(truncating: value) * Double(index + 1)
                    }
                }
                continuation.resume(returning: score)
            }
        }
        
        let technicalScore = await withCheckedContinuation { continuation in
            technicalInterpreter.run(inputs: inputs, options: ioOptions) { outputs, error in
                var score = 0.0
                if error == nil,
                   let outputs = outputs,
                   let output = try? outputs.output(index: 0) as? [[NSNumber]],
                   let probabilities = output.first {
                    for (index, value) in probabilities.enumerated() {
                        score += Double(truncating: value) * Double(index + 1)
                    }
                }
                continuation.resume(returning: score)
            }
        }
        
        // Return mean score
        return (aestheticScore + technicalScore) / 2
    }
    
    static func resizeImageIfNeeded(_ image: UIImage) -> UIImage {
        // If image is already large enough, return as is
        if image.size.width >= 224 && image.size.height >= 224 {
            return image
        }
        
        // Calculate scale needed to make both dimensions >= 224
        let widthRatio = 224 / image.size.width
        let heightRatio = 224 / image.size.height
        let scale = max(widthRatio, heightRatio)
        let newSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage ?? image
    }
}
