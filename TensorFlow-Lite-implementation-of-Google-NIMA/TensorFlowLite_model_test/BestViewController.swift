//
//  BestViewController.swift
//  TensorFlowLite_model_test
//
//  Created by Sophie Berger on 16.07.19.
//  Copyright © 2019 SophieMBerger. All rights reserved.
//

import UIKit
import Firebase
import FirebaseMLCommon

class BestViewController: UIViewController {
    
    @IBOutlet var bestMeanScoreLabel: UILabel!
    @IBOutlet var bestImageView: UIImageView!
    
    var viewController = ViewController()
    var aesthetic = 0.0
    var technical = 0.0
    var bestMeanScore = 0.0
    var nameOfBestImage = ""
    
    // Creating an interpreter from the models
    let aestheticOptions = ModelOptions(
        remoteModelName: "aesthetic_model",
        localModelName: "aesthetic_model")
    
    let technicalOptions = ModelOptions(
        remoteModelName: "technical_model",
        localModelName: "technical_model")
    
    var aestheticInterpreter: ModelInterpreter!
    var technicalInterpreter: ModelInterpreter!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set navigation title
        title = "Best Photo"
        
        // Configure UI
        bestMeanScoreLabel.textAlignment = .center
        bestImageView.contentMode = .scaleAspectFit
        bestImageView.clipsToBounds = true
        
        // Add share button
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .action,
            target: self,
            action: #selector(shareBestPhoto)
        )
    }
    
    @objc private func shareBestPhoto() {
        guard let image = bestImageView.image else { return }
        
        let activityVC = UIActivityViewController(
            activityItems: [
                image,
                "Photo Score: \(String(format: "%.2f", bestMeanScore))"
            ],
            applicationActivities: nil
        )
        
        // For iPad
        if let popoverController = activityVC.popoverPresentationController {
            popoverController.barButtonItem = navigationItem.rightBarButtonItem
        }
        
        present(activityVC, animated: true)
    }
}
