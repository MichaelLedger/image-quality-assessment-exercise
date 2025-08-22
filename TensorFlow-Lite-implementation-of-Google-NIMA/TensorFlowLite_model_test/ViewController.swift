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
import Vision // For ImageAestheticsScoresObservation

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, PHPickerViewControllerDelegate {
    
    // Maximum number of recent photos to analyze
    private let maxPhotoCount = 50 //test 500
    private var selectedPhotos: [SelectedPhoto] = []
    private var bestPhoto: (image: UIImage?, imageName: String?, asset: PHAsset?, score: Double)?
    private var scoredPhotos: [ScoredPhoto] = []
    private var processingQueue = DispatchQueue(label: "com.app.imageScoring", qos: .userInitiated)
    private var lastProcessingTime: TimeInterval = 0
    private let floatingButton = FloatingButton(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
    
    @IBOutlet private var meanLabel: UILabel!
    @IBOutlet private var aestheticLabel: UILabel!
    @IBOutlet private var technicalLabel: UILabel!
    @IBOutlet private var inputImageView: UIImageView!
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
            let photoImage = UIImage(systemName: "photo.on.rectangle", withConfiguration: config)
            let testPhotosButton = UIBarButtonItem(image: photoImage, style: .plain, target: self, action: #selector(testPhotosButtonTapped))
            
            navigationItem.rightBarButtonItem = testPhotosButton
            
            // Left buttons
            let gridImage = UIImage(systemName: "square.grid.3x3", withConfiguration: config)
            let showGridButton = UIBarButtonItem(image: gridImage, style: .plain, target: self, action: #selector(showScoredPhotosButtonTapped))
            
            let trophyImage = UIImage(systemName: "trophy", withConfiguration: config)
            let bestPhotoButton = UIBarButtonItem(image: trophyImage, style: .plain, target: self, action: #selector(findBestPhotoTapped))
            
            navigationItem.leftBarButtonItems = [showGridButton, bestPhotoButton]
        } else {
            // Fallback for iOS 12 and earlier
            let testPhotosButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(testPhotosButtonTapped))
            navigationItem.rightBarButtonItem = testPhotosButton
            
            // Left buttons for iOS 12
            let showGridButton = UIBarButtonItem(title: "Grid", style: .plain, target: self, action: #selector(showScoredPhotosButtonTapped))
            let bestPhotoButton = UIBarButtonItem(title: "Best", style: .plain, target: self, action: #selector(findBestPhotoTapped))
            navigationItem.leftBarButtonItems = [showGridButton, bestPhotoButton]
        }
        
        picker.delegate = self
        picker.dataSource = self
        
        // Setup floating button
        setupFloatingButton()
        
        //test
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
            firstPhoto.loadImage { [weak self] image in
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
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    self.fetchRecentPhotos()
                case .limited:
                    self.fetchRecentPhotos()
                default:
                    break
                }
            }
        }
    }
    
    private func fetchRecentPhotos() {
        // Create fetch options
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = maxPhotoCount
        
        // Fetch the most recent photos
        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        // Clear existing photos
        //selectedPhotos.removeAll()
        
        // Create dispatch group to wait for all photos to be processed
        let group = DispatchGroup()
        
        // Request image data for each asset
        assets.enumerateObjects { [weak self] (asset, index, stop) in
            guard let self = self else { return }
            
            group.enter()
            
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .exact // Get the exact size we request
            // mnt/Dataset/anse_data/IQAdata/koniq-10k/512x384
            // Request a larger size for better quality
            //let targetSize = CGSize(width: 512, height: 512)//CGSize(width: 1024, height: 1024)
            // Check asset dimensions before adding
            if asset.pixelWidth > 224 && asset.pixelHeight > 224 {
                self.selectedPhotos.append(SelectedPhoto.fromAsset(asset))
            }
            group.leave()
        }
        
        // Update UI when all photos are processed
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
            // Sort photos by creation date (most recent first)
            self.selectedPhotos.sort { $0.creationDate ?? Date() > $1.creationDate ?? Date() }
            
            // Update picker
            self.picker.reloadAllComponents()
            
            // Load initial image if we have photos
            if let firstPhoto = self.selectedPhotos.first {
                firstPhoto.loadImage { [weak self] image in
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
    
    @objc private func testPhotosButtonTapped() {
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch status {
                case .authorized, .restricted:
                    self.showImagePicker()
                case .denied:
                    self.showPhotoLibraryAccessAlert()
                case .notDetermined:
                    // The user hasn't determined this yet, request authorization will be called again
                    break
                case .limited:
                    // Show picker with option to add more photos
                    self.showImagePickerWithLimitedAccess()
                @unknown default:
                    break
                }
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
    
    @objc private func syncScoredPhoto() {
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
                    score: score
                )
                newScoredPhotos.append(scoredPhoto)
                continue
            }
        }
        self.scoredPhotos = newScoredPhotos.sorted { $0.score > $1.score }
    }
    
    @objc private func scoreAllSelectedPhotos(completion: (() -> Void)? = nil) {
        // Show loading indicator
        let loadingAlert = UIAlertController(
            title: "Processing Photos",
            message: "Analyzing with NIMA...",
            preferredStyle: .alert
        )
        self.present(loadingAlert, animated: true)
        processingQueue.async {
            // Process all selected photos
            let startTime = Date()
            let group = DispatchGroup()
            var newScoredPhotos: [ScoredPhoto] = []
            for photo in self.selectedPhotos {
                group.enter()
                
                // check if photos scored in finding best photo
                if let scoredPhoto = self.selectedPhotos.first(where: { selected in
                    selected.assetIdentifier == photo.assetIdentifier &&
                    selected.modificationDate == photo.modificationDate &&
                    selected.score != nil
                }), let score = scoredPhoto.score, score > 0 {
                    let scoredPhoto = ScoredPhoto(
                        assetIdentifier: photo.assetIdentifier,
                        localImageName: photo.localImageName,
                        modificationDate: photo.modificationDate,
                        score: score
                    )
                    newScoredPhotos.append(scoredPhoto)
                    group.leave()
                    continue
                }
                
                // Check if photo was already scored (by modification date)
                //            if let existingScore = self.scoredPhotos.first(where: { scored in
                //                scored.assetIdentifier == photo.assetIdentifier &&
                //                scored.modificationDate == photo.modificationDate
                //            }) {
                //                newScoredPhotos.append(existingScore)
                //                group.leave()
                //                continue
                //            }
                
                photo.loadImage { imageResult in
                    // Prepare and score local image
                    guard let image = imageResult,
                          let cgImage = image.cgImage,
                          let inputs = self.prepareImage(fromBestScore: true, withCGImage: cgImage) else {
                        group.leave()
                        return
                    }
                    
                    // Score the image
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
                                    
                                    // Update selected photo score
                                    if photo.assetIdentifier != nil {
                                        if let index = self.selectedPhotos.firstIndex(where: { $0.assetIdentifier == photo.assetIdentifier }) {
                                            var updatedPhoto = self.selectedPhotos[index]
                                            updatedPhoto.updateScore(meanScore)
                                            self.selectedPhotos[index] = updatedPhoto
                                        }
                                    } else if photo.localImageName != nil {
                                        if let index = self.selectedPhotos.firstIndex(where: { $0.localImageName == photo.localImageName }) {
                                            var updatedPhoto = self.selectedPhotos[index]
                                            updatedPhoto.updateScore(meanScore)
                                            self.selectedPhotos[index] = updatedPhoto
                                        }
                                    }
                                    
                                    // Create scored photo
                                    let scoredPhoto = ScoredPhoto(
                                        assetIdentifier: photo.assetIdentifier,
                                        localImageName: photo.localImageName,
                                        modificationDate: photo.modificationDate,
                                        score: meanScore
                                    )
                                    newScoredPhotos.append(scoredPhoto)
                                } else {
                                    print("Technical model error: \(error?.localizedDescription ?? "unknown error")")
                                }
                                group.leave()
                            }
                        } else {
                            group.leave()
                        }
                    }
                }
            }
            
            /*
             // Process local images from bundle if not already scored
             for imageName in self.imageNamesArray {
             group.enter()
             
             // Check if image was already scored
             if let existingScore = self.scoredPhotos.first(where: { $0.localImageName == imageName }) {
             newScoredPhotos.append(existingScore)
             group.leave()
             continue
             }
             
             // Prepare and score local image
             guard let image = UIImage(named: imageName),
             let cgImage = image.cgImage,
             let inputs = self.prepareImage(fromBestScore: true, withCGImage: cgImage) else {
             group.leave()
             continue
             }
             
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
             
             self.technicalInterpreter.run(inputs: inputs, options: self.ioOptions) { outputs, error in
             if error == nil, let outputs = outputs,
             let output = try? outputs.output(index: 0) as? [[NSNumber]] {
             let probabilities = output[0]
             for value in probabilities {
             guard let index = probabilities.firstIndex(of: value) else { continue }
             technicalScore += Double(truncating: value) * Double(index + 1)
             }
             
             let meanScore = (aestheticScore + technicalScore) / 2
             
             // Create scored photo
             let scoredPhoto = ScoredPhoto(
             assetIdentifier: nil,
             localImageName: imageName,
             modificationDate: Date(),
             score: meanScore
             )
             newScoredPhotos.append(scoredPhoto)
             }
             group.leave()
             }
             } else {
             group.leave()
             }
             }
             }
             */
            
            group.notify(queue: .main) {
                // Update scored photos
                self.scoredPhotos = newScoredPhotos.sorted { $0.score > $1.score }
                self.lastProcessingTime = Date().timeIntervalSince(startTime)
                loadingAlert.dismiss(animated: true)
                if let completion {
                    completion()
                }
            }
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
                if score > highestScore {
                    highestScore = score
                    currentPhoto.loadImage { image in
                        DispatchQueue.main.async {
                            self.bestPhoto = (image: image, imageName: currentPhoto.localImageName, asset: nil, score: score)
                        }
                    }
                }
                group.leave()
                continue
            }
            
            // Load and process photo
            currentPhoto.loadImage { [weak self] image in
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
                                DispatchQueue.main.async {
                                    if meanScore > highestScore {
                                        highestScore = meanScore
                                        self.bestPhoto = (image: image, imageName: self.selectedPhotos[photoIndex].localImageName, asset: nil, score: meanScore)
                                    }
                                }
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
    
    @objc private func floatingButtonTapped() {
        let alert = UIAlertController(
            title: "Choose Scoring Algorithm",
            message: "Select the algorithm to score your photos",
            preferredStyle: .actionSheet
        )
        
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
    
    @available(iOS 18.0, *)
    private func calculateAestheticsScore(image: UIImage) async throws -> ImageAestheticsScoresObservation? {
        // Convert UIImage to CIImage
        guard let ciImage = CIImage(image: image) else { return nil }
        
        // Set up the calculate image aesthetics scores request
        let request = CalculateImageAestheticsScoresRequest()
        
        // Perform the request
        return try await request.perform(on: ciImage)
    }
    
    @available(iOS 18.0, *)
    private func scoreWithVision() {
        let loadingAlert = UIAlertController(
            title: "Processing Photos",
            message: "Analyzing with Vision framework...",
            preferredStyle: .alert
        )
        present(loadingAlert, animated: true)
        
        let startTime = Date()
        let group = DispatchGroup()
        
        for photoIndex in selectedPhotos.indices {
            group.enter()
            
            selectedPhotos[photoIndex].loadImage { [weak self] image in
                guard let self = self,
                      let image = image else {
                    group.leave()
                    return
                }
                
                Task {
                    do {
                        if let observation = try await self.calculateAestheticsScore(image: image) {
                            // Convert score from -1...1 to 1...10 to match NIMA scale
                            let normalizedScore = ((observation.overallScore + 1) / 2) * 9 + 1
                            
                            // Add utility info to picker display
                            let isUtility = observation.isUtility
                            DispatchQueue.main.async {
                                self.selectedPhotos[photoIndex].updateScore(Double(normalizedScore), isUtility: isUtility)
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
            
            loadingAlert.dismiss(animated: true) {
                // Show completion alert
                let alert = UIAlertController(
                    title: "Analysis Complete",
                    message: "Processed \(self.selectedPhotos.count) photos in \(String(format: "%.2f", self.lastProcessingTime)) seconds",
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
                
                // Reload picker to show new scores
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
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        let photo = selectedPhotos[row]
        if let name = photo.localImageName, !name.isEmpty {
            if let score = photo.score {
                return "\(String(format: "%.2f", score)) \(name)"
            } else {
                return name
            }
        } else {
            let date = photo.creationDate ?? Date()
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            let dateString = formatter.string(from: date)
            var displayText = dateString
            if let score = photo.score {
                displayText += " \(String(format: "%.2f", score))"
                if let isUtility = photo.isUtility {
                    displayText += isUtility ? " 📄" : " 📸"
                }
            }
            return displayText
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let photo = selectedPhotos[row]
        
        // Show loading indicator
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.startAnimating()
        inputImageView.addSubview(activityIndicator)
        activityIndicator.center = inputImageView.center
        
        // Load image
        photo.loadImage { [weak self] image in
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
