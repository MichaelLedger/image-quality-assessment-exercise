import UIKit
import Photos
import Vision

extension ViewController {
    func setupFloatingButton() {
        let floatingButton = FloatingButton(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
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
    
    @objc func floatingButtonTapped() {
        let alert = UIAlertController(
            title: "Choose Action",
            message: "Select what you want to do with your photos",
            preferredStyle: .actionSheet
        )
        
        // Album Type Actions
        let albumsTitle = "Albums"
        let momentsAction = UIAlertAction(title: "📅 \(albumsTitle) by Moments", style: .default) { [weak self] _ in
            self?.showMomentsAlbum()
        }
        
        let locationAction = UIAlertAction(title: "📍 \(albumsTitle) by Locations", style: .default) { [weak self] _ in
            self?.showLocationAlbum()
        }
        
        // Configuration Actions
        let configurePhotoLimitAction = UIAlertAction(title: "⚙️ Configure Photo Limit", style: .default) { [weak self] _ in
            self?.configureMaxPhotoCount()
        }
        
        let configureLabelFiltersAction = UIAlertAction(title: "🏷️ Configure Label Filters", style: .default) { [weak self] _ in
            self?.configureLabelFiltering()
        }
        
        // Scoring Actions
        let nimaAction = UIAlertAction(title: "🤖 Score by NIMA (Aesthetic + Technical)", style: .default) { [weak self] _ in
            guard let self = self else { return }
            //clear all scores in selectedPhotos
            self.selectedPhotos = selectedPhotos.map { photo in
                var updatedPhoto = photo
                updatedPhoto.updateScore(nil, isUtility: photo.isUtility)
                return updatedPhoto
            }
            self.scoreAllSelectedPhotos { [weak self] in
                guard let self = self else { return }
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

        // Add all actions with grouping
        // Album Actions
        alert.addAction(momentsAction)
        alert.addAction(locationAction)
        
        // Configuration Actions
        alert.addAction(configurePhotoLimitAction)
        alert.addAction(configureLabelFiltersAction)
        
        // Scoring Actions
        alert.addAction(nimaAction)
        if #available(iOS 18.0, *) {
            let visionAction = UIAlertAction(title: "🎨 Score by Vision Aesthetics", style: .default) { [weak self] _ in
                self?.scoreWithVision()
            }
            alert.addAction(visionAction)
        }
        
        // Single Photo Actions
        let singlePhotoNIMAAction = UIAlertAction(title: "📸 Score Single Photo (NIMA)", style: .default) { [weak self] _ in
            let imagePicker = CustomImagePicker()
            imagePicker.delegate = self
            imagePicker.sourceType = .photoLibrary
            imagePicker.scoringType = .nima
            self?.present(imagePicker, animated: true)
        }
        alert.addAction(singlePhotoNIMAAction)
        if #available(iOS 18.0, *) {
            let singlePhotoVisionAction = UIAlertAction(title: "📸 Score Single Photo (Vision)", style: .default) { [weak self] _ in
                let imagePicker = CustomImagePicker()
                imagePicker.delegate = self
                imagePicker.sourceType = .photoLibrary
                imagePicker.scoringType = .vision
                self?.present(imagePicker, animated: true)
            }
            alert.addAction(singlePhotoVisionAction)
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // For iPad
        if let popoverController = alert.popoverPresentationController {
            popoverController.sourceView = view
            popoverController.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }
        
        present(alert, animated: true)
    }
    
    @MainActor
    func showMomentsAlbum() {
        Task {
            let loadingAlert = UIAlertController(title: nil, message: "Processing photos...", preferredStyle: .alert)
            let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
            loadingIndicator.hidesWhenStopped = true
            loadingIndicator.style = .medium
            loadingIndicator.startAnimating()
            loadingAlert.view.addSubview(loadingIndicator)
            present(loadingAlert, animated: true)
            
            do {
                let photos = try await PhotoManager.shared.fetchMomentsAlbums(fetchLimit: 500)
                dismiss(animated: true)
                let collectionVC = PhotoCollectionViewController()
                collectionVC.photos = photos
                navigationController?.pushViewController(collectionVC, animated: true)
            } catch {
                dismiss(animated: true)
                // Handle error appropriately
                let errorAlert = UIAlertController(
                    title: "Error",
                    message: "Failed to fetch photos: \(error.localizedDescription)",
                    preferredStyle: .alert
                )
                errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                present(errorAlert, animated: true)
            }
        }
    }
    
    @MainActor
    func showLocationAlbum() {
        Task {
            let loadingAlert = UIAlertController(title: nil, message: "Processing photos...", preferredStyle: .alert)
            let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
            loadingIndicator.hidesWhenStopped = true
            loadingIndicator.style = .medium
            loadingIndicator.startAnimating()
            loadingAlert.view.addSubview(loadingIndicator)
            present(loadingAlert, animated: true)
            
            do {
                let photos = try await PhotoManager.shared.fetchLocationAlbums(fetchLimit: 500)
                dismiss(animated: true)
                let collectionVC = PhotoCollectionViewController()
                collectionVC.photos = photos
                navigationController?.pushViewController(collectionVC, animated: true)
            } catch {
                dismiss(animated: true)
                // Handle error appropriately
                let errorAlert = UIAlertController(
                    title: "Error",
                    message: "Failed to fetch photos: \(error.localizedDescription)",
                    preferredStyle: .alert
                )
                errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                present(errorAlert, animated: true)
            }
        }
    }
    
    // MARK: - Image Picker Delegate
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        
        guard let image = info[.originalImage] as? UIImage else { return }
        
        // Get asset identifier if available
        let assetIdentifier = (info[.phAsset] as? PHAsset)?.localIdentifier
        let location = (info[.phAsset] as? PHAsset)?.location
        
        if #available(iOS 18.0, *), let customPicker = picker as? CustomImagePicker, customPicker.scoringType == .vision {
            // Score with Vision
            Task {
                await handleVisionScoring(image: image, assetIdentifier: assetIdentifier, location: location)
            }
        } else {
            // Score with NIMA
            guard let cgImage = image.cgImage,
                  let preparedInputs = prepareImage(fromBestScore: false, withCGImage: cgImage) else { return }
            
            // Start label detection in parallel
            Task {
                let detectedLabel = await detectLabel(for: image)
                
                // Get Location Name
                var locationName: String? = nil
                if let photoLocation = location {
                    locationName = await LocationManager.shared.getLocationName(for: photoLocation)
                }
                
                // Create completion handler for technical model
                let handleTechnicalScore: (Double, Double) -> Void = { [weak self, assetIdentifier] aestheticScore, technicalScore in
                    let meanScore = (aestheticScore + technicalScore) / 2
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        let previewVC = PhotoPreviewViewController()
                        let scoredPhoto = ScoredPhoto(
                            assetIdentifier: assetIdentifier,
                            localImageName: nil,
                            modificationDate: Date(),
                            score: meanScore,
                            label: detectedLabel ?? "Unknown",
                            location: location,
                            locationName: locationName
                        )
                        previewVC.scoredPhoto = scoredPhoto
                        self.navigationController?.pushViewController(previewVC, animated: true)
                    }
                }
                
                // Create completion handler for aesthetic model
                let handleAestheticScore: (Double) -> Void = { [weak self] aestheticScore in
                    guard let self = self else { return }
                    
                    // Run technical model
                    self.technicalInterpreter.run(inputs: preparedInputs, options: self.ioOptions) { outputs, error in
                        guard error == nil,
                              let outputs = outputs,
                              let output = try? outputs.output(index: 0) as? [[NSNumber]],
                              let probabilities = output.first else { return }
                        
                        var technicalScore = 0.0
                        for (index, value) in probabilities.enumerated() {
                            technicalScore += Double(truncating: value) * Double(index + 1)
                        }
                        
                        handleTechnicalScore(aestheticScore, technicalScore)
                    }
                }
                
                // Run aesthetic model
                aestheticInterpreter.run(inputs: preparedInputs, options: ioOptions) { outputs, error in
                    guard error == nil,
                          let outputs = outputs,
                          let output = try? outputs.output(index: 0) as? [[NSNumber]],
                          let probabilities = output.first else { return }
                    
                    var aestheticScore = 0.0
                    for (index, value) in probabilities.enumerated() {
                        aestheticScore += Double(truncating: value) * Double(index + 1)
                    }
                    
                    handleAestheticScore(aestheticScore)
                }
            }
        }
    }
    
    private func detectLabel(for image: UIImage) async -> String? {
        guard let cgImage = image.cgImage else { return nil }
        
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
            
            // Get all observations with confidence > 0.75 and join their identifiers
            if let observations = request.results?.filter({ $0.confidence > 0.75 }).sorted(by: { $0.confidence > $1.confidence }), !observations.isEmpty {
                let labels = observations.map { $0.identifier.lowercased() }
                return labels.joined(separator: "/")
            }
        } catch {
            print("Vision label detection failed: \(error)")
        }
        
        return nil
    }
    
    @available(iOS 18.0, *)
    private func handleVisionScoring(image: UIImage, assetIdentifier: String?, location: CLLocation?) async {
        do {
            // Get Vision score and label in parallel
            async let aestheticsTask = calculateAestheticsScore(image: image)
            async let labelTask = detectLabel(for: image)
            
            let (observation, detectedLabel) = await (try aestheticsTask, labelTask)
            
            // Get Location Name
            var locationName: String? = nil
            if let photoLocation = location {
                locationName = await LocationManager.shared.getLocationName(for: photoLocation)
            }
            
            // Calculate score and label
            var score: Float = 0
            var label: String = detectedLabel ?? "Unknown"
            
            if let observation {
                score = ((observation.overallScore + 1) / 2) * 9 + 1
            }
            if observation?.isUtility == true {
                label += " (isUtility)"
            }
            
            // Create scored photo
            let scoredPhoto = ScoredPhoto(
                assetIdentifier: assetIdentifier,
                localImageName: nil,
                modificationDate: Date(),
                score: Double(score),
                label: label,
                location: location,
                locationName: locationName
            )
            
            // Show preview on main thread
            await MainActor.run {
                let previewVC = PhotoPreviewViewController()
                previewVC.scoredPhoto = scoredPhoto
                navigationController?.pushViewController(previewVC, animated: true)
            }
        } catch {
            print("Vision analysis failed: \(error)")
        }
    }
}

