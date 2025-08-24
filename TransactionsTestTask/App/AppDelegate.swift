//
//  AppDelegate.swift
//  TransactionsTestTask
//
//

import UIKit
import Combine

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    private var bag = Set<AnyCancellable>()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        ServicesAssembler.analyticsService().eventsPublisher
            .sink { event in
                print("[Analytics]", event.name, event.parameters, event.date)
            }
            .store(in: &bag)

        ServicesAssembler.startRateObservers()
        ServicesAssembler.startRateUpdatesUseCase().start(every: 180) // 3mins
        return true
    }
    
    // MARK: UISceneSession Lifecycle
    
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
}
