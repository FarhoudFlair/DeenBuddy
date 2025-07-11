import Foundation

// MARK: - Shared Service Instances

/// Provides shared instances for services that need singleton access
public class SharedInstances {
    
    /// Shared error handler
    @MainActor
    public static let errorHandler = ErrorHandler(crashReporter: CrashReporter())
    
    /// Shared localization service  
    @MainActor
    public static let localizationService = LocalizationService()
    
    /// Shared analytics service
    @MainActor 
    public static let analyticsService = AnalyticsService()
    
    /// Shared accessibility service
    @MainActor
    public static let accessibilityService = AccessibilityService()
    
    private init() {}
}