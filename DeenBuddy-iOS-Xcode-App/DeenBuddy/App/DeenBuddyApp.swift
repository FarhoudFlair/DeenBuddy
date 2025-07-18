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
            EnhancedDeenAssistApp(coordinator: appCoordinator)
        }
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
                LoadingView.prayer(message: "Loading DeenBuddy...")

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
