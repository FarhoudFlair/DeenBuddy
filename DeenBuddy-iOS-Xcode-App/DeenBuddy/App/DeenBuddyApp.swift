//
//  DeenBuddyApp.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-03.
//

import SwiftUI

@main
struct DeenBuddyApp: App {
    private let appCoordinator = AppCoordinator.production()

    var body: some Scene {
        WindowGroup {
            DeenAssistApp(coordinator: appCoordinator)
        }
    }
}
