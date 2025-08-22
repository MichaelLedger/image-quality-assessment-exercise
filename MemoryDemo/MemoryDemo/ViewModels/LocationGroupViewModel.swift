import Photos
import Combine
import CoreLocation

class LocationGroupViewModel {
    @Published private(set) var locationGroups: [LocationGroupCellViewModel] = []
    private var cancellables = Set<AnyCancellable>()
    private let operationQueue = OperationQueue()
    private var currentOperation: Operation?
    private let targetSize = CGSize(width: 400, height: 400)
    
    init() {
        setupRecommendationSubscription()
        operationQueue.maxConcurrentOperationCount = 1
    }
    
    private func setupRecommendationSubscription() {
        PhotoRecommendManager.shared.recommendationPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] groupId, recommendedAssets in
                guard let self = self else { return }
                if let index = self.locationGroups.firstIndex(where: { $0.locationGroup.id == groupId }) {
                    self.locationGroups[index].updateRecommendedAssets(recommendedAssets)
                }
            }
            .store(in: &cancellables)
    }
    
    func analyzePhotosByDistance(thresholdKM: Double = 50.0) {
        // 取消当前正在执行的操作
        currentOperation?.cancel()
        PhotoRecommendManager.shared.cancelAllProcessing()
        
        let operation = BlockOperation()
        operation.addExecutionBlock { [weak self, weak operation] in
            guard let self = self, let operation = operation else { return }
            
            let assets = PHAsset.fetchAssets(with: self.option)
            var locationGroups: [[PHAsset]] = []
            
            assets.enumerateObjects { asset, _, _ in
                if operation.isCancelled { return }
                
                guard let location = asset.location else {
                    return
                }
                
                var added = false
                for i in 0..<locationGroups.count {
                    if let firstLocation = locationGroups[i].first?.location {
                        let distance = location.distance(from: firstLocation) / 1000.0
                        if distance < thresholdKM {
                            locationGroups[i].append(asset)
                            added = true
                            break
                        }
                    }
                }
                
                if !added {
                    locationGroups.append([asset])
                }
            }
            
            if operation.isCancelled { return }
            var filteredGroups = locationGroups// locationGroups.filter { $0.count > 5 }//test
            if let maxGroup = filteredGroups.max(by: { $0.count < $1.count }) {
                filteredGroups.removeAll { $0 == maxGroup }
            }
            let viewModels = filteredGroups
                .map { assets -> LocationGroupCellViewModel in
                    let location = assets.first!.location!
                    let locationGroup = LocationGroup(assets: assets, location: location)
                    let viewModel = LocationGroupCellViewModel(locationGroup: locationGroup)
                    if !operation.isCancelled {
                        PhotoRecommendManager.shared.processLocationGroup(locationGroup)
                    }
                    return viewModel
                }
            
            if operation.isCancelled { return }
            self.locationGroups = viewModels
        }
        
        currentOperation = operation
        operationQueue.addOperation(operation)
    }
    
    func getPhotoLibraryMoments() {
        currentOperation?.cancel()
        PhotoRecommendManager.shared.cancelAllProcessing()
        
        let operation = BlockOperation()
        operation.addExecutionBlock { [weak self, weak operation] in
            guard let self = self, let operation = operation else { return }
            
            let result = PHAssetCollection.fetchMoments(with: nil)
            var locationGroups: [[PHAsset]] = []
            let groupLock = NSLock()
            
            result.enumerateObjects(options: .concurrent) { collection, _, _ in
                if operation.isCancelled { return }
                guard collection.approximateLocation != nil else { return }
                
                let assets = PHAsset.fetchAssets(in: collection, options: self.option)
                let assetsLock = NSLock()
                var loadAssets: [PHAsset] = []
                
                assets.enumerateObjects(options: .concurrent) { asset, _, _ in
                    if operation.isCancelled { return }
                    guard let location = asset.location else {//test
                        return
                    }
                    assetsLock.lock()
                    loadAssets.append(asset)
                    assetsLock.unlock()
                }
                
                if !loadAssets.isEmpty && !operation.isCancelled {
                    groupLock.lock()
                    locationGroups.append(loadAssets)
                    groupLock.unlock()
                }
            }
            
            if operation.isCancelled { return }
            
            // 先找出并移除最大的组
            var filteredGroups = locationGroups //locationGroups.filter { $0.count > 5 }  //test
            if let maxGroup = filteredGroups.max(by: { $0.count < $1.count }) {
                filteredGroups.removeAll { $0 == maxGroup }
            }
            
            let viewModels = filteredGroups
                .sorted { $0.first?.creationDate ?? Date() > $1.first?.creationDate ?? Date() }
                .map { assets -> LocationGroupCellViewModel in
                    let location = assets.first!.location!
                    let locationGroup = LocationGroup(assets: assets, location: location)
                    let viewModel = LocationGroupCellViewModel(locationGroup: locationGroup)
                    if !operation.isCancelled {
                        PhotoRecommendManager.shared.processLocationGroup(locationGroup)
                    }
                    return viewModel
                }
            
            if operation.isCancelled {
                return
            }
            
            DispatchQueue.main.async {
                debugPrint("\(viewModels.map {$0.locationGroup.assets.count}.reduce(0, +))========\(Date())")
                self.locationGroups = viewModels
            }
        }
        
        currentOperation = operation
        operationQueue.addOperation(operation)
    }
    
    var option: PHFetchOptions {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        return fetchOptions
    }
}
