//
//  AppDelegate.swift
//  TensorFlowLite_model_test
//
//  Created by Sophie Berger on 12.07.19.
//  Copyright © 2019 SophieMBerger. All rights reserved.
//

import UIKit
import Firebase
import FirebaseMLCommon

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        FirebaseApp.configure()
        
        // Load local models
        guard let aestheticModelPath = Bundle.main.path(forResource: "aesthetic_model", ofType: "tflite")
            else {
                // Invalid model path
                return false
        }
        let aestheticLocalModel = LocalModel(name: "aesthetic_model", path: aestheticModelPath)
        ModelManager.modelManager().register(aestheticLocalModel)
        
        guard let technicalModelPath = Bundle.main.path(forResource: "technical_model", ofType: "tflite")
            else {
                // Invalid model path
                return false
        }
        let technicalLocalModel = LocalModel(name: "technical_model", path: technicalModelPath)
        ModelManager.modelManager().register(technicalLocalModel)
        
        // Loading the remote aesthetic and technical models
        let initialConditions = ModelDownloadConditions(
            allowsCellularAccess: true,
            allowsBackgroundDownloading: true
        )

        let updateConditions = ModelDownloadConditions(
            allowsCellularAccess: false,
            allowsBackgroundDownloading: true
        )

        let aestheticModel = RemoteModel(
            name: "aesthetic_model",
            allowsModelUpdates: true,
            initialConditions: initialConditions,
            updateConditions: updateConditions
        )

        let technicalModel = RemoteModel(
            name: "technical_model",
            allowsModelUpdates: true,
            initialConditions: initialConditions,
            updateConditions: updateConditions
        )

        ModelManager.modelManager().register(aestheticModel)
        ModelManager.modelManager().register(technicalModel)
        
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        let configuration = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }


}

