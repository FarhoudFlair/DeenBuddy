import Foundation

@MainActor
class AppDependencyContainer: ObservableObject {
    static let shared = AppDependencyContainer()
    
    // Use the DependencyContainer internally
    private let coreContainer = DependencyContainer.shared
    
    private init() {
        // Empty init since DeenAssistCore.DependencyContainer handles initialization
    }
    
    // MARK: - Resolvers
    
    func resolveLocationService() -> (any LocationServiceProtocol)? {
        return coreContainer.locationService
    }
    
    func resolveAPIClient() -> (any APIClientProtocol)? {
        return coreContainer.apiClient
    }
    
    func resolveNotificationService() -> (any NotificationServiceProtocol)? {
        return coreContainer.notificationService
    }
    
    func resolvePrayerTimeService() -> (any PrayerTimeServiceProtocol)? {
        return coreContainer.prayerTimeService
    }
    
    func resolveSettingsService() -> (any SettingsServiceProtocol)? {
        return coreContainer.settingsService
    }

    func resolveBackgroundTaskManager() -> BackgroundTaskManager? {
        return coreContainer.backgroundTaskManager
    }

    func resolveBackgroundPrayerRefreshService() -> BackgroundPrayerRefreshService? {
        return coreContainer.backgroundPrayerRefreshService
    }
    
    // Generic resolver for compatibility
    func resolve<Service>(_ serviceType: Service.Type) -> Service? {
        switch serviceType {
        case let type as (any LocationServiceProtocol).Type:
            return coreContainer.locationService as? Service
        case let type as (any APIClientProtocol).Type:
            return coreContainer.apiClient as? Service
        case let type as (any NotificationServiceProtocol).Type:
            return coreContainer.notificationService as? Service
        case let type as (any PrayerTimeServiceProtocol).Type:
            return coreContainer.prayerTimeService as? Service
        case let type as (any SettingsServiceProtocol).Type:
            return coreContainer.settingsService as? Service
        default:
            return nil
        }
    }
    
    // Access to the core container for views that need the full DependencyContainer
    func getCoreContainer() -> DependencyContainer {
        return coreContainer
    }
}
