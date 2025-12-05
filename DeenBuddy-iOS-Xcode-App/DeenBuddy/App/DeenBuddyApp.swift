//
//  DeenBuddyApp.swift
//  DeenBuddy
//
//  Created by Farhoud Talebi on 2025-07-03.
//

import SwiftUI
import UIKit

@main
struct DeenBuddyApp: App {
    @UIApplicationDelegateAdaptor(DeenBuddyAppDelegate.self) var appDelegate
    private let appCoordinator: AppCoordinator
    @StateObject private var userPreferencesService: UserPreferencesService

    init() {
        // Ensure Firebase is configured before any services (e.g., AppCoordinator) touch Auth/Firestore
        FirebaseInitializer.configureIfNeeded()
        self.appCoordinator = AppCoordinator.production()
        self._userPreferencesService = StateObject(wrappedValue: UserPreferencesService())
    }

    var body: some Scene {
        WindowGroup {
            EnhancedDeenAssistApp(coordinator: appCoordinator)
                .environmentObject(userPreferencesService)
                .onOpenURL { url in
                    // Handle magic link URLs
                    appCoordinator.handleMagicLink(url)
                }
        }
    }
}

final class DeenBuddyAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        return true
    }
}

/// Enhanced app view that uses the custom MainTabView for better settings integration
struct EnhancedDeenAssistApp: View {
    @StateObject private var coordinator: AppCoordinator

    init(coordinator: AppCoordinator) {
        self._coordinator = StateObject(wrappedValue: coordinator)
    }

    var body: some View {
        ZStack {
            switch coordinator.currentScreen {
            case .loading:
                LoadingView.prayerWithMascot(message: "Loading DeenBuddy...")

            case .onboarding(let step):
                OnboardingCoordinatorView(
                    step: step,
                    coordinator: coordinator
                )

            case .home:
                MainTabView(coordinator: coordinator)
            }
        }
        .onAppear {
            coordinator.start()
        }
    }
}
