import SwiftUI
import DeenAssistUI
import DeenAssistProtocols

@main
struct DeenAssistMainApp: App {
    
    // MARK: - App Coordinator
    
    @StateObject private var coordinator = AppCoordinator.production()
    
    // MARK: - App Body
    
    var body: some Scene {
        WindowGroup {
            DeenAssistApp(coordinator: coordinator)
                .onAppear {
                    setupApp()
                }
        }
    }
    
    // MARK: - App Setup
    
    private func setupApp() {
        // Configure app-wide settings
        configureAppearance()
        
        // Start location services if needed
        startLocationServices()
    }
    
    private func configureAppearance() {
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        
        // Configure tab bar appearance if needed in future
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor.systemBackground
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }
    
    private func startLocationServices() {
        // Location services will be started when needed by the coordinator
        // This is just a placeholder for any initial setup
    }
}

// MARK: - App Info

extension Bundle {
    var appName: String {
        return infoDictionary?["CFBundleDisplayName"] as? String ?? 
               infoDictionary?["CFBundleName"] as? String ?? 
               "Deen Assist"
    }
    
    var appVersion: String {
        return infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    var buildNumber: String {
        return infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
