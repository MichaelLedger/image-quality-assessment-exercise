//
//  ViewController.swift
//  TensorFlowLite_model_test
//
//  Created by Sophie Berger on 12.07.19.
//  Copyright © 2019 SophieMBerger. All rights reserved.
//

import UIKit
import Firebase
import FirebaseMLCommon
import Photos
import PhotosUI
import Vision

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, PHPickerViewControllerDelegate {
    
    internal var selectedPhotos: [SelectedPhoto] = []
    private var bestPhoto: (image: UIImage?, imageName: String?, asset: PHAsset?, score: Double)?
    internal var scoredPhotos: [ScoredPhoto] = []

    private var processingQueue = DispatchQueue(label: "com.app.imageScoring", qos: .userInitiated)
    internal var lastProcessingTime: TimeInterval = 0
    private let floatingButton = FloatingButton(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
    
    @IBOutlet internal var meanLabel: UILabel!
    @IBOutlet internal var aestheticLabel: UILabel!
    @IBOutlet internal var technicalLabel: UILabel!
    @IBOutlet internal var inputImageView: UIImageView!
    @IBOutlet private var picker: UIPickerView!
    //private var scoreRangeLabel: UILabel!
    
    var aesthetic = 0.0
    var technical = 0.0
    var inputs = ModelInputs()
    var ioOptions = ModelInputOutputOptions()
    
    // Creating an interpreter from the models
    let aestheticOptions = ModelOptions(
        remoteModelName: "aesthetic_model",
        localModelName: "aesthetic_model")
    
    let technicalOptions = ModelOptions(
        remoteModelName: "technical_model",
        localModelName: "technical_model")
    
    var aestheticInterpreter: ModelInterpreter!
    var technicalInterpreter: ModelInterpreter!
    
    var imageNamesArray = ["jump-1209647_640",
                           "42039",
                           "42040",
                           "42041",
                           "42042",
                           "42044",
                           "antelope-canyon-1128815_640",
                           "architecture-768432_640",
                           "baby-1151351_640",
                           "beach-84533_640",
                           "beach-1236581_640",
                           "blue-1845901_640",
                           "boat-house-192990_640",
                           "bridge-53769_640",
                           "buildings-1245953_640",
                           "california-1751455_640",
                           "canyon-4245261_640",
                           "castle-505878_640",
                           "children-1822704_640",
                           "cinque-terre-279013_640",
                           "city-647400_640",
                           "clouds-4261864_640",
                           "country-house-540796_640",
                           "dolphin-203875_640",
                           "father-656734_640",
                           "fireworks",
                           "fishermen-504098_640",
                           "fountain-197334_640",
                           "fountain-461552_640",
                           "fountain-675488_640",
                           "fox-1284512_640",
                           "godafoss-1840758_640",
                           "horse-1330690_640",
                           "hotelRoom",
                           "iceland-1979445_640",
                           "imagineCup",
                           "IMG_0825",
                           "IMG_1629",
                           "IMG_1630",
                           "IMG_1633",
                           "IMG_5519",
                           "IMG_8624",
                           "IMG_8829",
                           "italy-1587287_640",
                           "italy-2273767_640",
                           "japan-2014618_640",
                           "japanese-cherry-trees-324175_640",
                           "ladybugs-1593406_640",
                           "legs-434918_640",
                           "lighthouse-1034003_640",
                           "lion",
                           "maldives-666122_640",
                           "Microsoft",
                           "milky-way-916523_640",
                           "moon-1859616_640",
                           "moon-2245743_640",
                           "nature-1547302_640",
                           "netherlands-685392_640",
                           "neuschwanstein-castle-467116_640",
                           "new-years-eve-1953253_640",
                           "openEyes",
                           "pedestrians-400811_640",
                           "people-3104635_640",
                           "person-1245959_640"]
     
    @MainActor
    internal func configureMaxPhotoCount() {
        Task {
            let currentCount = await PhotoManager.shared.maxPhotoCount
            
            let alert = UIAlertController(
                title: "Configure Photo Limit",
                message: "Enter maximum number of photos to analyze (0 for no limit)",
                preferredStyle: .alert
            )
            
            alert.addTextField { textField in
                textField.keyboardType = .numberPad
                textField.text = String(currentCount)
                textField.placeholder = "Enter number (0 for no limit)"
            }
            
            alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                guard let self = self,
                      let text = alert.textFields?.first?.text,
                      let count = Int(text) else { return }
                
                Task {
                    await PhotoManager.shared.updateMaxPhotoCount(count)
                    self.checkPhotoLibraryAuthorizationAndFetchPhotos()
                }
            })
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            present(alert, animated: true)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup score range label
        //        scoreRangeLabel = UILabel()
        //        scoreRangeLabel.translatesAutoresizingMaskIntoConstraints = false
        //        scoreRangeLabel.textAlignment = .center
        //        scoreRangeLabel.font = .systemFont(ofSize: 12, weight: .regular)
        //        scoreRangeLabel.textColor = .gray
        //        scoreRangeLabel.text = "Score Range: 1-10 (Higher is better)"
        //        view.addSubview(scoreRangeLabel)
        
        // Add constraints for score range label
        //        NSLayoutConstraint.activate([
        //            scoreRangeLabel.topAnchor.constraint(equalTo: meanLabel.bottomAnchor, constant: 8),
        //            scoreRangeLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        //            scoreRangeLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        //        ])
        
        // Add test photos button to navigation bar
        // Configure navigation bar buttons
        if #available(iOS 13.0, *) {
            let config = UIImage.SymbolConfiguration(pointSize: 21, weight: .medium)
            
            // Right button - Photo Library
            //let photoImage = UIImage(systemName: "photo.on.rectangle", withConfiguration: config)
            //let testPhotosButton = UIBarButtonItem(image: photoImage, style: .plain, target: self, action: #selector(testPhotosButtonTapped))
            //navigationItem.rightBarButtonItem = testPhotosButton
            
            // Left buttons
            let gridImage = UIImage(systemName: "square.grid.3x3", withConfiguration: config)
            let showGridButton = UIBarButtonItem(image: gridImage, style: .plain, target: self, action: #selector(showScoredPhotosButtonTapped))
            
            let trophyImage = UIImage(systemName: "trophy", withConfiguration: config)
            let bestPhotoButton = UIBarButtonItem(image: trophyImage, style: .plain, target: self, action: #selector(findBestPhotoTapped))
            
            navigationItem.leftBarButtonItems = [showGridButton, bestPhotoButton]
        } else {
            // Fallback for iOS 12 and earlier
            //let testPhotosButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(testPhotosButtonTapped))
            //navigationItem.rightBarButtonItem = testPhotosButton
            
            // Left buttons for iOS 12
            let showGridButton = UIBarButtonItem(title: "Grid", style: .plain, target: self, action: #selector(showScoredPhotosButtonTapped))
            let bestPhotoButton = UIBarButtonItem(title: "Best", style: .plain, target: self, action: #selector(findBestPhotoTapped))
            navigationItem.leftBarButtonItems = [showGridButton, bestPhotoButton]
        }
        navigationItem.rightBarButtonItem = nil
        
        picker.delegate = self
        picker.dataSource = self
        
        // Setup floating button
        setupFloatingButton()
        
        //ignore local images for now
        // Add local images to selectedPhotos
        /*
         for imageName in imageNamesArray {
         let photo = SelectedPhoto(
         assetIdentifier: nil,
         localImageName: imageName,
         creationDate: Date(),  // Use current date for local images
         modificationDate: Date(),
         score: nil
         )
         selectedPhotos.append(photo)
         }
         */
        
        // Fetch recent photos if authorized
        checkPhotoLibraryAuthorizationAndFetchPhotos()
        
        aestheticInterpreter = ModelInterpreter.modelInterpreter(options: aestheticOptions)
        technicalInterpreter = ModelInterpreter.modelInterpreter(options: technicalOptions)
        
        // Specifying the I/O format of the models
        let ioOptions = ModelInputOutputOptions()
        do {
            try ioOptions.setInputFormat(index: 0, type: .float32, dimensions: [1, 224, 224, 3])
            try ioOptions.setOutputFormat(index: 0, type: .float32, dimensions: [1, 10])
        } catch let error as NSError {
            print("Failed to set input or output format with error: \(error.localizedDescription)")
        }
        self.ioOptions = ioOptions
        
        // Load and process first image
        if let firstPhoto = selectedPhotos.first {
            firstPhoto.loadImage(targetSize: .zero) { [weak self] image in
                guard let self = self,
                      let image = image,
                      let cgImage = image.cgImage else { return }
                
                DispatchQueue.main.async {
                    self.inputImageView.image = image
                    if let preparedInputs = self.prepareImage(fromBestScore: false, withCGImage: cgImage) {
                        self.inputs = preparedInputs
                        self.runModels(
                            fromBestScore: false,
                            nameOfInputImage: firstPhoto.localImageName ?? "",
                            aestheticInterpreter: self.aestheticInterpreter,
                            technicalInterpreter: self.technicalInterpreter,
                            inputs: preparedInputs,
                            ioOptions: self.ioOptions,
                            sender: nil
                        )
                    }
                }
            }
        }
    }
    
    func prepareImage(fromBestScore: Bool, inputImageTitle: String? = nil, withCGImage: CGImage? = nil) -> ModelInputs? {
        // Set and prepare the input image
        let image: CGImage
        
        if let cgImage = withCGImage {
            image = cgImage
        } else if let title = inputImageTitle, let cgImage = UIImage(named: title)?.cgImage {
            image = cgImage
            if !fromBestScore {
                inputImageView.image = UIImage(cgImage: image)
            }
        } else {
            return nil
        }
        
        guard let context = CGContext(
            data: nil,
            width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else { return ModelInputs()}
        
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let imageData = context.data else { return ModelInputs()}
        
        let inputs = ModelInputs()
        var inputData = Data()
        do {
            for row in 0 ..< 224 {
                for col in 0 ..< 224 {
                    let offset = 4 * (col * context.width + row)
                    // (Ignore offset 0, the unused alpha channel)
                    let red = imageData.load(fromByteOffset: offset+1, as: UInt8.self)
                    let green = imageData.load(fromByteOffset: offset+2, as: UInt8.self)
                    let blue = imageData.load(fromByteOffset: offset+3, as: UInt8.self)
                    
                    // Normalize channel values to [0.0, 1.0]. This requirement varies
                    // by model. For example, some models might require values to be
                    // normalized to the range [-1.0, 1.0] instead, and others might
                    // require fixed-point values or the original bytes.
                    
                    var normalizedRed = Float32(red) / 255.0
                    var normalizedGreen = Float32(green) / 255.0
                    var normalizedBlue = Float32(blue) / 255.0
                    
                    // Append normalized values to Data object in RGB order.
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
            try inputs.addInput(inputData)
        } catch let error {
            print("Failed to add input: \(error)")
        }
        return inputs
    }
    
    func runModels(fromBestScore: Bool, nameOfInputImage: String? = nil, aestheticInterpreter: ModelInterpreter, technicalInterpreter: ModelInterpreter, inputs: ModelInputs, ioOptions: ModelInputOutputOptions, sender: BestViewController? = nil) {
        
        aestheticInterpreter.run(inputs: inputs, options: ioOptions) { outputs, error in
            self.aesthetic = 0.0
            self.technical = 0.0
            
            guard error == nil, let outputs = outputs else { return }
            // Process outputs
            // Get first and only output of inference with a batch size of 1
            let output = try? outputs.output(index: 0) as? [[NSNumber]]
            let probabilities = output?[0]
            
            for value in probabilities! {
                guard let index = probabilities?.firstIndex(of: value) else { return }
                // To get the over all score multiply each score between 1 and 10 by the probability of having said score and then add them together
                self.aesthetic += Double(truncating: value) * Double(index + 1)
            }
            if !fromBestScore {
                self.aestheticLabel.text = "The aesthetic score is: \(String(format: "%.2f", self.aesthetic)) / 10"
            }
        }
        
        technicalInterpreter.run(inputs: inputs, options: ioOptions) { outputs, error in
            guard error == nil, let outputs = outputs else { return }
            // Process outputs
            // Get first and only output of inference with a batch size of 1
            let output = try? outputs.output(index: 0) as? [[NSNumber]]
            let probabilities = output?[0]
            
            for value in probabilities! {
                guard let index = probabilities?.firstIndex(of: value) else { return }
                // To get the over all score multiply each score between 1 and 10 by the probability of having said score and then add them together
                self.technical += Double(truncating: value) * Double(index + 1)
            }
            if !fromBestScore {
                self.technicalLabel.text = "The technical score is: \(String(format: "%.2f", self.technical)) / 10"
                let meanScore = (self.aesthetic + self.technical) / 2
                self.meanLabel.text = "The average score is: \(String(format: "%.2f", meanScore)) / 10"
            } else {
                let currentMeanScore = (self.aesthetic + self.technical) / 2
                if currentMeanScore > sender!.bestMeanScore {
                    sender!.bestMeanScore = currentMeanScore
                    sender!.nameOfBestImage = nameOfInputImage!
                    
                    sender!.bestImageView.image = UIImage(named: sender!.nameOfBestImage)
                    sender!.bestMeanScoreLabel.text = "The best mean score is: \(sender!.bestMeanScore)"
                }
            }
        }
    }
    
    // MARK: - Photo Library Methods
    
    private func checkPhotoLibraryAuthorizationAndFetchPhotos() {
        Task {
            // Show loading alert
            let loadingAlert = UIAlertController(
                title: "Loading Photos",
                message: "Fetching recent photos(filter duplicated/similar/labels)...",
                preferredStyle: .alert
            )
            await MainActor.run {
                present(loadingAlert, animated: true)
            }
            
            let startTime = Date()
            
            // Set default values if not already set
            if UserDefaults.standard.object(forKey: PreferenceKeys.maxPhotoCount) == nil {
                await PhotoManager.shared.updateMaxPhotoCount(500) // Default value
            }
            // Fetch photos using shared manager
            let photos = await PhotoManager.shared.fetchRecentPhotos(maxPhotoCount: PhotoManager.shared.maxPhotoCount)
            
            let currentCount = await PhotoManager.shared.maxPhotoCount
            // Update UI on main thread
            await MainActor.run {
                self.selectedPhotos = photos
                
                // Dismiss loading alert
                loadingAlert.dismiss(animated: true) {
                    // Calculate processing time
                    let processingTime = Date().timeIntervalSince(startTime)
                    
                    // Show completion alert with processing time
                    let completionAlert = UIAlertController(
                        title: "Photos Filtered and Loaded",
                        message: "Fetched \(self.selectedPhotos.count) photos from \(currentCount) in \(String(format: "%.2f", processingTime)) seconds",
                        preferredStyle: .alert
                    )
                    completionAlert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(completionAlert, animated: true)
                }
                
                // Update picker
                self.picker.reloadAllComponents()
                
                // Load initial image if we have photos
                if let firstPhoto = self.selectedPhotos.first {
                    firstPhoto.loadImage(targetSize: .zero) { [weak self] image in
                        guard let self = self,
                              let image = image,
                              let cgImage = image.cgImage else { return }
                        
                        DispatchQueue.main.async {
                            self.inputImageView.image = image
                            if let preparedInputs = self.prepareImage(fromBestScore: false, withCGImage: cgImage) {
                                self.runModels(
                                    fromBestScore: false,
                                    aestheticInterpreter: self.aestheticInterpreter,
                                    technicalInterpreter: self.technicalInterpreter,
                                    inputs: preparedInputs,
                                    ioOptions: self.ioOptions
                                )
                            }
                        }
                    }
                }
            }
        }
    }
    
    @objc private func testPhotosButtonTapped() async {
        await requestAuthorizationForTestPhotos()
    }
    
    private func requestAuthorizationForTestPhotos() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        DispatchQueue.main.async {
            switch status {
            case .authorized:
                self.showImagePicker()
            case .denied:
                self.showPhotoLibraryAccessAlert()
            case .notDetermined:
                // The user hasn't determined this yet, request authorization will be called again
                break
            case .limited, .restricted:
                // Show picker with option to add more photos
                self.showImagePickerWithLimitedAccess()
            @unknown default:
                break
            }
        }
    }
    
    private func showImagePicker() {
        if #available(iOS 14, *) {
            var config = PHPickerConfiguration()
            config.selectionLimit = 1  // 0 means no limit
            config.filter = .images
            
            let picker = PHPickerViewController(configuration: config)
            picker.delegate = self
            present(picker, animated: true)
        } else {
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.sourceType = .photoLibrary
            present(imagePicker, animated: true)
        }
    }
    
    private func showImagePickerWithLimitedAccess() {
        if #available(iOS 14, *) {
            var config = PHPickerConfiguration(photoLibrary: .shared())
            config.selectionLimit = 1  // 0 means no limit
            config.filter = .images
            config.preferredAssetRepresentationMode = .current
            
            let picker = PHPickerViewController(configuration: config)
            picker.delegate = self
            
            // Create buttons for the toolbar
            let selectMoreButton = UIBarButtonItem(title: "Select More Photos", style: .plain, target: self, action: #selector(selectMorePhotosTapped))
            let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            let changeAccessButton = UIBarButtonItem(title: "Change Access", style: .plain, target: self, action: #selector(changePhotoAccessTapped))
            
            // Create and configure toolbar
            let toolbar = UIToolbar()
            toolbar.items = [selectMoreButton, flexSpace, changeAccessButton]
            toolbar.sizeToFit()
            
            // Add toolbar to the picker
            picker.view.addSubview(toolbar)
            
            // Position toolbar at the bottom
            toolbar.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                toolbar.leadingAnchor.constraint(equalTo: picker.view.leadingAnchor),
                toolbar.trailingAnchor.constraint(equalTo: picker.view.trailingAnchor),
                toolbar.bottomAnchor.constraint(equalTo: picker.view.safeAreaLayoutGuide.bottomAnchor)
            ])
            
            present(picker, animated: true)
        } else {
            showImagePicker()
        }
    }
    
    @objc private func selectMorePhotosTapped() {
        if #available(iOS 14, *) {
            PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: self)
        }
    }
    
    @objc private func changePhotoAccessTapped() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }
        
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    @objc private func showScoredPhotosButtonTapped() {
        self.scoreAllSelectedPhotos { [weak self] in
            guard let self else {return}
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                // Show processing time alert
                let timeAlert = UIAlertController(
                    title: "Analysis Complete",
                    message: "Analyzed \(self.selectedPhotos.count) photos\nProcessing time: \(String(format: "%.2f", self.lastProcessingTime)) seconds",
                    preferredStyle: .alert
                )
                timeAlert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                    // Dismiss loading and show collection
                    let photoCollectionVC = PhotoCollectionViewController()
                    self.syncScoredPhoto()
                    photoCollectionVC.photos = self.scoredPhotos
                    self.navigationController?.pushViewController(photoCollectionVC, animated: true)
                })
                self.present(timeAlert, animated: true)
            }
        }
    }
    
    @objc internal func syncScoredPhoto() {
        var newScoredPhotos: [ScoredPhoto] = []
        for photo in self.selectedPhotos {
            // check if photos scored in finding best photo
            if let scoredPhoto = self.selectedPhotos.first(where: { selected in
                selected.assetIdentifier == photo.assetIdentifier &&
                selected.modificationDate == photo.modificationDate &&
                selected.score != nil
            }), let score = scoredPhoto.score {
                let scoredPhoto = ScoredPhoto(
                    assetIdentifier: photo.assetIdentifier,
                    localImageName: photo.localImageName,
                    modificationDate: photo.modificationDate,
                    score: score,
                    label: photo.label,
                    location: photo.location,
                    locationName: photo.locationName
                )
                newScoredPhotos.append(scoredPhoto)
                continue
            }
        }
        self.scoredPhotos = newScoredPhotos.sorted { $0.score > $1.score }
    }
    
    private func processPhoto(_ photo: SelectedPhoto, photosToProcess: [SelectedPhoto]) async -> ScoredPhoto? {
        // Check if photo was already scored
        if let scoredPhoto = photosToProcess.first(where: { selected in
            selected.assetIdentifier == photo.assetIdentifier &&
            selected.modificationDate == photo.modificationDate &&
            selected.score != nil
        }), let score = scoredPhoto.score, score > 0 {
            return ScoredPhoto(
                assetIdentifier: photo.assetIdentifier,
                localImageName: photo.localImageName,
                modificationDate: photo.modificationDate,
                score: score,
                label: photo.label,
                location: photo.location,
                locationName: photo.locationName
            )
        }
        
        // Load and process image
        guard let image = await photo.loadImage(targetSize: .zero),
              let cgImage = image.cgImage else {
            return nil
        }
        
        // Prepare image inputs
        guard let inputs = prepareImage(fromBestScore: true, withCGImage: cgImage) else {
            return nil
        }
        
        // Score the image using async/await wrapper
        let (aestheticScore, technicalScore) = await scoreImage(inputs: inputs)
        let meanScore = (aestheticScore + technicalScore) / 2
        
        // Create scored photo
        return ScoredPhoto(
            assetIdentifier: photo.assetIdentifier,
            localImageName: photo.localImageName,
            modificationDate: photo.modificationDate,
            score: meanScore,
            label: photo.label,
            location: photo.location,
            locationName: photo.locationName
        )
    }
    
    private func scoreImage(inputs: ModelInputs) async -> (aesthetic: Double, technical: Double) {
        await withCheckedContinuation { continuation in
            aestheticInterpreter.run(inputs: inputs, options: ioOptions) { outputs, error in
                var aesthetic = 0.0
                
                if error == nil, let outputs = outputs,
                   let output = try? outputs.output(index: 0) as? [[NSNumber]] {
                    let probabilities = output[0]
                    for value in probabilities {
                        guard let index = probabilities.firstIndex(of: value) else { continue }
                        aesthetic += Double(truncating: value) * Double(index + 1)
                    }
                    
                    // Run technical model
                    self.technicalInterpreter.run(inputs: inputs, options: self.ioOptions) { outputs, error in
                        var technical = 0.0
                        if error == nil, let outputs = outputs,
                           let output = try? outputs.output(index: 0) as? [[NSNumber]] {
                            let probabilities = output[0]
                            for value in probabilities {
                                guard let index = probabilities.firstIndex(of: value) else { continue }
                                technical += Double(truncating: value) * Double(index + 1)
                            }
                        }
                        continuation.resume(returning: (aesthetic, technical))
                    }
                } else {
                    continuation.resume(returning: (0.0, 0.0))
                }
            }
        }
    }
    
    @MainActor
    private func updateUIWithResults(_ newScoredPhotos: [ScoredPhoto], loadingAlert: UIAlertController, startTime: Date, completion: (() -> Void)?) {
        // Update scored photos - sort by modification date (newest first) like system Photos app
        scoredPhotos = newScoredPhotos.sorted { $0.score > $1.score }
        lastProcessingTime = Date().timeIntervalSince(startTime)
        loadingAlert.dismiss(animated: true)
        completion?()
    }
    
    @MainActor
    @objc internal func scoreAllSelectedPhotos(completion: (() -> Void)? = nil) {
        Task {
            // Show loading indicator
            let loadingAlert = UIAlertController(
                title: "Processing Photos",
                message: "Analyzing...",
                preferredStyle: .alert
            )
            present(loadingAlert, animated: true)
            
            // Process all selected photos
            let startTime = Date()
            var newScoredPhotos: [ScoredPhoto] = []
            
            // Create a local copy of selectedPhotos to avoid data races
            let photosToProcess = selectedPhotos
            
            // Process in smaller batches
            let batchSize = 20 // Reduced batch size for better progress tracking
            
            // Process each batch sequentially
            for batch in stride(from: 0, to: photosToProcess.count, by: batchSize) {
                let end = min(batch + batchSize, photosToProcess.count)
                let batchPhotos = Array(photosToProcess[batch..<end])
                let batchNumber = batch/batchSize + 1
                let totalBatches = (photosToProcess.count + batchSize - 1) / batchSize
                
                await MainActor.run {
                    //loadingAlert.message = "Processing batch \(batchNumber)/\(totalBatches)..."
                    loadingAlert.message = "Processing photo \(batch)/\(photosToProcess.count)..."
                }
                
                print("Starting batch \(batchNumber) of \(totalBatches)...")
                
                // Process photos in this batch concurrently
                await withTaskGroup(of: ScoredPhoto?.self) { group in
                    for (index, photo) in batchPhotos.enumerated() {
                        group.addTask { [weak self] in
                            guard let self = self else { return nil }
                            print("Batch \(batchNumber): Processing photo \(index + 1)/\(batchPhotos.count)")
                            let scoredPhoto = await self.processPhoto(photo, photosToProcess: photosToProcess)
                            // Calculate the actual index in selectedPhotos array
                            let actualIndex = batch + index
                            await MainActor.run {
                                self.selectedPhotos[actualIndex].updateScore(scoredPhoto?.score)
                            }
                            return scoredPhoto
                        }
                    }
                    
                    // Collect results from this batch
                    for await scoredPhoto in group {
                        if let scoredPhoto {
                            newScoredPhotos.append(scoredPhoto)
                            print("Successfully processed photo. Total processed: \(newScoredPhotos.count)/\(photosToProcess.count)")
                        }
                    }
                }
                
                print("Batch \(batchNumber) completed. Processed \(end) of \(photosToProcess.count) photos. Successfully processed: \(newScoredPhotos.count)")
            }
            
            // Update UI with results
            updateUIWithResults(newScoredPhotos, loadingAlert: loadingAlert, startTime: startTime, completion: completion)
        }
    }
    
    @objc private func findBestPhotoTapped() {
        guard !selectedPhotos.isEmpty else {
            // Show alert if no photos are available
            let alert = UIAlertController(
                title: "No Photos Available",
                message: "Please select photos from your library first.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        
        // Show loading indicator
        let loadingAlert = UIAlertController(
            title: "Analyzing Photos",
            message: "Analyzing \(selectedPhotos.count) photos to find the best one...",
            preferredStyle: .alert
        )
        present(loadingAlert, animated: true)
        
        // Reset best photo and start timer
        bestPhoto = nil
        var highestScore = 0.0
        let startTime = Date()
        let group = DispatchGroup()
        
        // Process each photo
        for photoIndex in selectedPhotos.indices {
            group.enter()
            
            let currentPhoto = selectedPhotos[photoIndex]
            
            if let score = currentPhoto.score, score > 0 {
                // Update best photo if score is higher
//                if score > highestScore {
//                    highestScore = score
//                    currentPhoto.loadImage(targetSize: .zero) { image in
//                        DispatchQueue.main.async {
//                            self.bestPhoto = (image: image, imageName: currentPhoto.localImageName, asset: nil, score: score)
//                        }
//                    }
//                }
                group.leave()
                continue
            }
            
            // Load and process photo
            currentPhoto.loadImage(targetSize: .zero) { [weak self] image in
                guard let self = self,
                      let image = image,
                      let cgImage = image.cgImage else {
                    group.leave()
                    return
                }
                guard let inputs = self.prepareImage(fromBestScore: true, withCGImage: cgImage) else {
                    group.leave()
                    return
                }
                
                // Run models
                self.aestheticInterpreter.run(inputs: inputs, options: self.ioOptions) { outputs, error in
                    var aestheticScore = 0.0
                    var technicalScore = 0.0
                    
                    if error == nil, let outputs = outputs,
                       let output = try? outputs.output(index: 0) as? [[NSNumber]] {
                        let probabilities = output[0]
                        for value in probabilities {
                            guard let index = probabilities.firstIndex(of: value) else { continue }
                            aestheticScore += Double(truncating: value) * Double(index + 1)
                        }
                        
                        // Run technical model
                        self.technicalInterpreter.run(inputs: inputs, options: self.ioOptions) { outputs, error in
                            if error == nil, let outputs = outputs,
                               let output = try? outputs.output(index: 0) as? [[NSNumber]] {
                                let probabilities = output[0]
                                for value in probabilities {
                                    guard let index = probabilities.firstIndex(of: value) else { continue }
                                    technicalScore += Double(truncating: value) * Double(index + 1)
                                }
                                
                                let meanScore = (aestheticScore + technicalScore) / 2
                                
                                // Update score in the array
                                DispatchQueue.main.async {
                                    self.selectedPhotos[photoIndex].updateScore(meanScore)
                                }
                                
                                // Update best photo if score is higher
//                                DispatchQueue.main.async {
//                                    if meanScore > highestScore {
//                                        highestScore = meanScore
//                                        self.bestPhoto = (image: image, imageName: self.selectedPhotos[photoIndex].localImageName, asset: nil, score: meanScore)
//                                    }
//                                }
                            }
                            group.leave()
                        }
                    } else {
                        group.leave()
                    }
                }
            }
        }
        
        // When all photos are processed
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            var highestScorePhoto: SelectedPhoto?
            // fetch highest scored photo from selectedPhotos once only
            for photo in selectedPhotos {
                if let score = photo.score, score > 0 {
                    // Update best photo if score is higher
                    if score > highestScore {
                        highestScore = score
                        highestScorePhoto = photo
                    }
                }
            }
            if let highestScorePhoto, let score = highestScorePhoto.score {
                highestScorePhoto.loadImage(targetSize: .zero) { image in
                    DispatchQueue.main.async {
                        self.bestPhoto = (image: image, imageName: highestScorePhoto.localImageName, asset: nil, score: score)
                    }
                }
            }
            
            // Calculate processing time
            self.lastProcessingTime = Date().timeIntervalSince(startTime)
            
            // Dismiss loading alert and show processing time
            loadingAlert.dismiss(animated: true) {
                // Show processing time alert
                let timeAlert = UIAlertController(
                    title: "Analysis Complete",
                    message: "Analyzed \(self.selectedPhotos.count) photos\nProcessing time: \(String(format: "%.2f", self.lastProcessingTime)) seconds",
                    preferredStyle: .alert
                )
                timeAlert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                    // Show best photo in BestViewController after time alert is dismissed
                    if let _ = self.bestPhoto {
                        // Perform the segue to BestViewController
                        self.performSegue(withIdentifier: "showBestSegue", sender: self)
                    } else {
                        // Show error if no best photo found
                        let alert = UIAlertController(
                            title: "Error",
                            message: """
                        Could not determine the best photo. Please try again.
                        Attempted to analyze \(self.selectedPhotos.count) photos
                        Processing time: \(String(format: "%.2f", self.lastProcessingTime)) seconds
                        """,
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(alert, animated: true)
                    }})
                self.present(timeAlert, animated: true)
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showBestSegue",
           let bestVC = segue.destination as? BestViewController,
           let bestPhoto = self.bestPhoto {
            
            bestVC.bestMeanScore = bestPhoto.score
            
            // Set a loading indicator
            let activityIndicator = UIActivityIndicatorView(style: .large)
            activityIndicator.startAnimating()
            bestVC.view.addSubview(activityIndicator)
            activityIndicator.center = bestVC.view.center
            
            // Set initial image if available
            if let image = bestPhoto.image {
                bestVC.bestImageView.image = image
            } else if let imageName = bestPhoto.imageName {
                bestVC.bestImageView.image = UIImage(named: imageName)
            }
            
            // Try to get high quality image if available
            if let asset = bestPhoto.asset {
                let options = PHImageRequestOptions()
                options.deliveryMode = .highQualityFormat
                options.isNetworkAccessAllowed = true
                options.isSynchronous = false
                options.resizeMode = .exact
                
                PHImageManager.default().requestImage(
                    for: asset,
                    targetSize: PHImageManagerMaximumSize,
                    contentMode: .aspectFit,
                    options: options
                ) { image, _ in
                    DispatchQueue.main.async {
                        activityIndicator.removeFromSuperview()
                        if let highQualityImage = image {
                            bestVC.bestImageView.image = highQualityImage
                        }
                    }
                }
            } else {
                activityIndicator.removeFromSuperview()
            }
            
            bestVC.bestMeanScoreLabel.text = """
                Best photo score: \(String(format: "%.2f", bestPhoto.score)) / 10
                Selected from \(self.selectedPhotos.count) photos
                Processing time: \(String(format: "%.2f", self.lastProcessingTime)) seconds
                """
        }
    }
    
    /*
    private func setupFloatingButton() {
        view.addSubview(floatingButton)
        
        // Position button in bottom-right corner
        floatingButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            floatingButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            floatingButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            floatingButton.widthAnchor.constraint(equalToConstant: 50),
            floatingButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        floatingButton.addTarget(self, action: #selector(floatingButtonTapped), for: .touchUpInside)
    }
     */
    
    @objc internal func configureLabelFiltering() {
        let alert = UIAlertController(
            title: "Configure Label Filtering",
            message: "Choose labels to include or exclude",
            preferredStyle: .actionSheet
        )
        
        // Add option to manage required labels
        alert.addAction(UIAlertAction(title: "Select Required Labels", style: .default) { [weak self] _ in
            self?.showLabelSelectionAlert(for: .required)
        })
        
        // Add option to manage excluded labels
        alert.addAction(UIAlertAction(title: "Select Excluded Labels", style: .default) { [weak self] _ in
            self?.showLabelSelectionAlert(for: .excluded)
        })
        
        // Add options for required labels
        alert.addAction(UIAlertAction(title: "Add Custom Required Labels", style: .default) { [weak self] _ in
            self?.showCustomLabelAlert(for: .required)
        })
        alert.addAction(UIAlertAction(title: "Remove Custom Required Labels", style: .default) { [weak self] _ in
            self?.showRemoveCustomLabelsAlert(for: .required)
        })
        
        // Add options for excluded labels
        alert.addAction(UIAlertAction(title: "Add Custom Excluded Labels", style: .default) { [weak self] _ in
            self?.showCustomLabelAlert(for: .excluded)
        })
        alert.addAction(UIAlertAction(title: "Remove Custom Excluded Labels", style: .default) { [weak self] _ in
            self?.showRemoveCustomLabelsAlert(for: .excluded)
        })
        
        // Add option to clear all filters
        alert.addAction(UIAlertAction(title: "Reset to Default (All Labels)", style: .destructive) { [weak self] _ in
            Task {
                await PhotoManager.shared.resetToDefaultLabels()
                // Refresh photos with new filter settings
                self?.checkPhotoLibraryAuthorizationAndFetchPhotos()
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // For iPad
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = floatingButton
            popoverController.sourceRect = floatingButton.bounds
        }
        
        present(alert, animated: true)
    }
    
    private enum LabelFilterType {
        case required
        case excluded
    }
    
    private func createLabelButton(label: String, index: Int, isSelected: Bool, filterType: LabelFilterType) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("\(isSelected ? "✓ " : "☐ ")\(label.description)", for: .normal)
        button.contentHorizontalAlignment = .left
        button.tag = index
        
        button.addAction(UIAction { [weak self] _ in
            Task {
                var isNowSelected = false
                
                switch filterType {
                case .required:
                    let currentRequired = await PhotoManager.shared.requiredLabels
                    if currentRequired.contains(label) {
                        let filtered = currentRequired.filter { $0 != label }
                        await PhotoManager.shared.updateRequiredLabels(filtered)
                    } else {
                        var updated = currentRequired
                        updated.insert(label)
                        await PhotoManager.shared.updateRequiredLabels(updated)
                        isNowSelected = true
                    }
                case .excluded:
                    let currentExcluded = await PhotoManager.shared.excludedLabels
                    if currentExcluded.contains(label) {
                        let filtered = currentExcluded.filter { $0 != label }
                        await PhotoManager.shared.updateExcludedLabels(filtered)
                    } else {
                        var updated = currentExcluded
                        updated.insert(label)
                        await PhotoManager.shared.updateExcludedLabels(updated)
                        isNowSelected = true
                    }
                }
                
                // Update button title to show selection state
                await MainActor.run {
                    button.setTitle("\(isNowSelected ? "✓ " : "☐ ")\(label.description)", for: .normal)
                }
                
                // Refresh photos with new filter settings
                self?.checkPhotoLibraryAuthorizationAndFetchPhotos()
            }
        }, for: .touchUpInside)
        
        return button
    }

    private func showLabelSelectionAlert(for filterType: LabelFilterType) {
        Task {
            let alert = UIAlertController(
                title: filterType == .required ? "Select Required Labels" : "Select Excluded Labels",
                message: "Select labels to \(filterType == .required ? "require" : "exclude")",
                preferredStyle: .alert
            )
            
            // Add a scrollable view for labels
            let scrollView = UIScrollView()
            scrollView.translatesAutoresizingMaskIntoConstraints = false
            
            let stackView = UIStackView()
            stackView.axis = .vertical
            stackView.spacing = 10
            stackView.translatesAutoresizingMaskIntoConstraints = false
            
            // Get labels based on filter type and current state
            let labelsSet = filterType == .required ? PhotoManager.shared.defaultLabels : PhotoManager.shared.defaultExcludedLabels
            let currentLabels = filterType == .required ? 
                await PhotoManager.shared.requiredLabels :
                await PhotoManager.shared.excludedLabels
            
            // Convert default labels to array and sort alphabetically (A to Z)
            let commonLabels = Array(labelsSet).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            
            // Create checkboxes for each default label
            for (index, label) in commonLabels.enumerated() {
                let isSelected = currentLabels.contains(label)
                let button = createLabelButton(label: label, index: index, isSelected: isSelected, filterType: filterType)
                stackView.addArrangedSubview(button)
            }
            
            scrollView.addSubview(stackView)
            alert.view.addSubview(scrollView)
            
            // Add constraints
            NSLayoutConstraint.activate([
                scrollView.topAnchor.constraint(equalTo: alert.view.topAnchor, constant: 50),
                scrollView.leadingAnchor.constraint(equalTo: alert.view.leadingAnchor, constant: 20),
                scrollView.trailingAnchor.constraint(equalTo: alert.view.trailingAnchor, constant: -20),
                scrollView.bottomAnchor.constraint(equalTo: alert.view.bottomAnchor, constant: -80),
                
                stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
                stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
                stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
                stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
                stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
            ])
            
            // Set alert size
            alert.view.heightAnchor.constraint(equalToConstant: 400).isActive = true
            
            // Add Done button that refreshes the photos
            alert.addAction(UIAlertAction(title: "Done", style: .default) { [weak self] _ in
                self?.checkPhotoLibraryAuthorizationAndFetchPhotos()
            })
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
            await MainActor.run {
                present(alert, animated: true)
            }
        }
    }
    
    private func showCustomLabelAlert(for filterType: LabelFilterType) {
        Task {
            let alert = UIAlertController(
                title: filterType == .required ? "Add Custom Required Label" : "Add Custom Excluded Label",
                message: "Enter a custom label to \(filterType == .required ? "require" : "exclude")",
                preferredStyle: .alert
            )
            
            // Add text field for custom label input
            alert.addTextField { textField in
                textField.placeholder = "Enter custom label"
                textField.autocapitalizationType = .none
                textField.returnKeyType = .done
                textField.clearButtonMode = .whileEditing
            }
            
            // Add button to add custom label
            alert.addAction(UIAlertAction(title: "Add Label", style: .default) { [weak self] _ in
                guard let textField = alert.textFields?.first,
                      let customLabel = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                      !customLabel.isEmpty else {
                    return
                }
                
                Task {
                    switch filterType {
                    case .required:
                        var currentRequired = await PhotoManager.shared.requiredLabels
                        currentRequired.insert(customLabel)
                        await PhotoManager.shared.updateRequiredLabels(currentRequired)
                    case .excluded:
                        var currentExcluded = await PhotoManager.shared.excludedLabels
                        currentExcluded.insert(customLabel)
                        await PhotoManager.shared.updateExcludedLabels(currentExcluded)
                    }
                    
                    // Refresh photos with new filter settings
                    self?.checkPhotoLibraryAuthorizationAndFetchPhotos()
                }
            })
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
            await MainActor.run {
                present(alert, animated: true)
            }
        }
    }
    
    private func showRemoveCustomLabelsAlert(for filterType: LabelFilterType) {
        Task {
            let alert = UIAlertController(
                title: filterType == .required ? "Remove Custom Required Labels" : "Remove Custom Excluded Labels",
                message: "Select labels to remove and tap Done",
                preferredStyle: .alert
            )
            
            // Add a scrollable view for labels
            let scrollView = UIScrollView()
            scrollView.translatesAutoresizingMaskIntoConstraints = false
            
            let stackView = UIStackView()
            stackView.axis = .vertical
            stackView.spacing = 10
            stackView.translatesAutoresizingMaskIntoConstraints = false
            
            // Get custom labels for the selected filter type
            let defaultLabels = filterType == .required ? PhotoManager.shared.defaultLabels : PhotoManager.shared.defaultExcludedLabels
            let currentLabels = filterType == .required ? 
                await PhotoManager.shared.requiredLabels :
                await PhotoManager.shared.excludedLabels
            
            let customLabels = currentLabels.subtracting(defaultLabels).sorted()
            
            // Track selected labels
            var selectedLabels = Set<String>()
            
            if !customLabels.isEmpty {
                for label in customLabels {
                    let container = UIView()
                    container.translatesAutoresizingMaskIntoConstraints = false
                    
                    let textLabel = UILabel()
                    textLabel.text = label
                    textLabel.translatesAutoresizingMaskIntoConstraints = false
                    
                    let selectButton = UIButton(type: .system)
                    selectButton.setTitle("☐ Select", for: .normal)
                    selectButton.translatesAutoresizingMaskIntoConstraints = false
                    
                    selectButton.addAction(UIAction { [weak selectButton] _ in
                        if selectedLabels.contains(label) {
                            selectedLabels.remove(label)
                            selectButton?.setTitle("☐ Select", for: .normal)
                        } else {
                            selectedLabels.insert(label)
                            selectButton?.setTitle("✓ Selected", for: .normal)
                        }
                    }, for: .touchUpInside)
                    
                    container.addSubview(textLabel)
                    container.addSubview(selectButton)
                    
                    NSLayoutConstraint.activate([
                        textLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                        textLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                        
                        selectButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                        selectButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                        selectButton.leadingAnchor.constraint(greaterThanOrEqualTo: textLabel.trailingAnchor, constant: 10),
                        
                        container.heightAnchor.constraint(equalToConstant: 30)
                    ])
                    
                    stackView.addArrangedSubview(container)
                }
            } else {
                let noLabelsLabel = UILabel()
                noLabelsLabel.text = "No custom labels added yet"
                noLabelsLabel.textColor = .gray
                noLabelsLabel.textAlignment = .center
                stackView.addArrangedSubview(noLabelsLabel)
            }
            
            scrollView.addSubview(stackView)
            alert.view.addSubview(scrollView)
            
            // Add constraints
            NSLayoutConstraint.activate([
                scrollView.topAnchor.constraint(equalTo: alert.view.topAnchor, constant: 80),
                scrollView.leadingAnchor.constraint(equalTo: alert.view.leadingAnchor, constant: 20),
                scrollView.trailingAnchor.constraint(equalTo: alert.view.trailingAnchor, constant: -20),
                scrollView.bottomAnchor.constraint(equalTo: alert.view.bottomAnchor, constant: -80),
                
                stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
                stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
                stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
                stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
                stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
            ])
            
            // Set alert size
            alert.view.heightAnchor.constraint(equalToConstant: 400).isActive = true
            
            // Add Done button that processes selected labels
            alert.addAction(UIAlertAction(title: "Done", style: .default) { [weak self] _ in
                guard !selectedLabels.isEmpty else { return }
                
                Task {
                    switch filterType {
                    case .required:
                        var currentRequired = await PhotoManager.shared.requiredLabels
                        for label in selectedLabels {
                            currentRequired.remove(label)
                        }
                        await PhotoManager.shared.updateRequiredLabels(currentRequired)
                    case .excluded:
                        var currentExcluded = await PhotoManager.shared.excludedLabels
                        for label in selectedLabels {
                            currentExcluded.remove(label)
                        }
                        await PhotoManager.shared.updateExcludedLabels(currentExcluded)
                    }
                    
                    // Refresh photos with new filter settings
                    self?.checkPhotoLibraryAuthorizationAndFetchPhotos()
                }
            })
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
            await MainActor.run {
                present(alert, animated: true)
            }
        }
    }
    
    /*
    @objc private func floatingButtonTapped() {
        let alert = UIAlertController(
            title: "Choose Scoring Algorithm",
            message: "Select the algorithm to score your photos",
            preferredStyle: .actionSheet
        )
        
        // Add configuration options
        alert.addAction(UIAlertAction(title: "Configure Photo Limit", style: .default) { [weak self] _ in
            self?.configureMaxPhotoCount()
        })
        
        alert.addAction(UIAlertAction(title: "Configure Label Filters", style: .default) { [weak self] _ in
            self?.configureLabelFiltering()
        })
        
        // Add NIMA option
        alert.addAction(UIAlertAction(title: "Aesthetic + Technical (NIMA)", style: .default) { [weak self] _ in
            guard let self else { return }
            //clear all scores in selectedPhotos
            self.selectedPhotos = selectedPhotos.map { photo in
                var updatedPhoto = photo
                updatedPhoto.updateScore(nil, isUtility: photo.isUtility)
                return updatedPhoto
            }
            self.scoreAllSelectedPhotos { [weak self] in
                guard let self else {return}
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    // Show processing time alert
                    let timeAlert = UIAlertController(
                        title: "Analysis Complete",
                        message: "Analyzed \(self.selectedPhotos.count) photos\nProcessing time: \(String(format: "%.2f", self.lastProcessingTime)) seconds",
                        preferredStyle: .alert
                    )
                    timeAlert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                        // Dismiss loading and show collection
                        let photoCollectionVC = PhotoCollectionViewController()
                        self.syncScoredPhoto()
                        photoCollectionVC.photos = self.scoredPhotos
                        self.navigationController?.pushViewController(photoCollectionVC, animated: true)
                    })
                    self.present(timeAlert, animated: true)
                }
            }
        })
        
        // Add Vision option for iOS 18+
        if #available(iOS 18.0, *) {
            alert.addAction(UIAlertAction(title: "Vision Aesthetics", style: .default) { [weak self] _ in
                self?.scoreWithVision()
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // For iPad
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = floatingButton
            popoverController.sourceRect = floatingButton.bounds
        }
        
        present(alert, animated: true)
    }
     */
    
    @available(iOS 18.0, *)
    internal func calculateAestheticsScore(image: UIImage) async throws -> ImageAestheticsScoresObservation? {
        // Convert UIImage to CIImage
        guard let ciImage = CIImage(image: image) else { return nil }
        
        // Set up the calculate image aesthetics scores request
        let request = CalculateImageAestheticsScoresRequest()
        
        // Perform the request
        return try await request.perform(on: ciImage)
    }
    
    @available(iOS 18.0, *)
    internal func scoreWithVision() {
        let loadingAlert = UIAlertController(
            title: "Processing Photos",
            message: "Analyzing with Vision framework...",
            preferredStyle: .alert
        )
        present(loadingAlert, animated: true)
        
        let startTime = Date()
        let group = DispatchGroup()
        
        // Track utility photos and scores
        var utilityIndices = Set<Int>()
        var photoScores = [(index: Int, score: Double)]()
        
        for photoIndex in selectedPhotos.indices {
            group.enter()
            selectedPhotos[photoIndex].loadImage(targetSize: .zero) { [weak self] image in
                guard let self = self,
                      let image = image else {
                    group.leave()
                    return
                }
                
                Task {
                    do {
                        if let observation = try await self.calculateAestheticsScore(image: image) {
                            if observation.isUtility {
                                // Mark as utility photo
                                utilityIndices.insert(photoIndex)
                            } else {
                                // Convert score from -1...1 to 1...10 to match NIMA scale
                                let normalizedScore = ((observation.overallScore + 1) / 2) * 9 + 1
                                photoScores.append((index: photoIndex, score: Double(normalizedScore)))
                            }
                        }
                    } catch {
                        print("Vision analysis failed: \(error)")
                    }
                    group.leave()
                }
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.lastProcessingTime = Date().timeIntervalSince(startTime)
            
            // Get total count before removing utility photos
            let totalCount = self.selectedPhotos.count
            
            // Create a map of which indices should be removed
            let utilitySet = Set(utilityIndices)
            
            // Create new array without utility photos and with proper scores
            self.selectedPhotos = self.selectedPhotos.enumerated().compactMap { (currentIndex, photo) in
                if utilitySet.contains(currentIndex) {
                    return nil // Filter out utility photos
                }
                
                // Find and apply score if available
                if let scoreInfo = photoScores.first(where: { $0.index == currentIndex }) {
                    var updatedPhoto = photo
                    updatedPhoto.updateScore(scoreInfo.score, isUtility: false)
                    return updatedPhoto
                }
                
                return photo
            }
            
            loadingAlert.dismiss(animated: true) {
                // Show completion alert
                let alert = UIAlertController(
                    title: "Analysis Complete",
                    message: """
                        Processed \(totalCount) photos:
                        • \(self.selectedPhotos.count) aesthetic photos scored
                        • \(utilityIndices.count) utility images removed
                        Time: \(String(format: "%.2f", self.lastProcessingTime)) seconds
                        """,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                    // Dismiss loading and show collection
                    let photoCollectionVC = PhotoCollectionViewController()
                    self.syncScoredPhoto()
                    photoCollectionVC.photos = self.scoredPhotos
                    self.navigationController?.pushViewController(photoCollectionVC, animated: true)
                })
                self.present(alert, animated: true)
                
                // Reload picker to show updated photos
                self.picker.reloadAllComponents()
            }
        }
    }
    
    private func showPhotoLibraryAccessAlert() {
        let alert = UIAlertController(
            title: "Photo Library Access Required",
            message: "Please enable photo library access in Settings to analyze your photos.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    // MARK: - UIImagePickerControllerDelegate
    /*
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        
        guard let image = info[.originalImage] as? UIImage,
              let cgImage = image.cgImage else { return }
        
        // Update UI
        inputImageView.image = image
        
        // Create inputs for the model
        //let inputs = ModelInputs()
        guard let preparedInputs = prepareImage(fromBestScore: false, withCGImage: cgImage) else { return }
        
        // Run the models
        runModels(fromBestScore: false, aestheticInterpreter: aestheticInterpreter, technicalInterpreter: technicalInterpreter, inputs: preparedInputs, ioOptions: ioOptions)
    }
     */
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
    
    // MARK: - PHPickerViewControllerDelegate
    
    @available(iOS 14, *)
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        
        guard !results.isEmpty else { return }
        
        // Process each selected image
        for result in results {
            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                if let error = error {
                    print("Error loading image: \(error.localizedDescription)")
                    return
                }
                
                guard let self = self,
                      let image = object as? UIImage,
                      let cgImage = image.cgImage else { return }
                
                DispatchQueue.main.async {
                    // Update UI with the last selected image
                    self.inputImageView.image = image
                    
                    // Create inputs for the model
                    guard let preparedInputs = self.prepareImage(fromBestScore: false, withCGImage: cgImage) else { return }
                    
                    // Run the models
                    self.runModels(fromBestScore: false, aestheticInterpreter: self.aestheticInterpreter, technicalInterpreter: self.technicalInterpreter, inputs: preparedInputs, ioOptions: self.ioOptions)
                }
            }
        }
    }
}

extension ViewController: UIPickerViewDelegate, UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return selectedPhotos.count
    }
    
    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        let photo = selectedPhotos[row]
        
        // Get the cached label if available
        let label = photo.label
        
        // Create mutable attributed string for styling
        let attributedText = NSMutableAttributedString()
        
        // Add score if available with blue color and smaller font
        if let score = photo.score {
            let scoreText = NSAttributedString(
                string: "[\(String(format: "%.2f", score))] ",
                attributes: [
                    .foregroundColor: UIColor.systemBlue,
                    .font: UIFont.systemFont(ofSize: 12, weight: .medium)
                ]
            )
            attributedText.append(scoreText)
        }
        
        // Add label with default color and normal size font
        let labelText = NSAttributedString(
            string: label ?? "unknown",
            attributes: [
                .foregroundColor: UIColor.darkText,
                .font: UIFont.systemFont(ofSize: 14, weight: .regular)
            ]
        )
        attributedText.append(labelText)
        
        return attributedText
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        guard selectedPhotos.count > row else { return }
        let photo = selectedPhotos[row]
        
        // Show loading indicator
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.startAnimating()
        inputImageView.addSubview(activityIndicator)
        activityIndicator.center = inputImageView.center
        
        // Load image
        photo.loadImage(targetSize: .zero) { [weak self] image in
            guard let self = self,
                  let image = image,
                  let cgImage = image.cgImage else {
                DispatchQueue.main.async {
                    activityIndicator.removeFromSuperview()
                }
                return
            }
            
            DispatchQueue.main.async {
                activityIndicator.removeFromSuperview()
                self.inputImageView.image = image
                
                if let preparedInputs = self.prepareImage(fromBestScore: false, withCGImage: cgImage) {
                    self.runModels(
                        fromBestScore: false,
                        aestheticInterpreter: self.aestheticInterpreter,
                        technicalInterpreter: self.technicalInterpreter,
                        inputs: preparedInputs,
                        ioOptions: self.ioOptions
                    )
                }
            }
        }
    }
    
}
