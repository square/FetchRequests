//
//  AppDelegate.swift
//  iOS Example
//
//  Created by Adam Lickel on 7/2/19.
//  Copyright © 2019 Speramus Inc. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(
            rootViewController: ViewController()
        )
        window?.makeKeyAndVisible()
        
        return true
    }
}
