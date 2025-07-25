// MARK: - DeenAssist Core Module
// This module provides all the core functionality for the DeenBuddy iOS app
// including location services, API integration, notification management, and Islamic feature flags.

import Foundation

// MARK: - Version Information
public struct DeenAssistCore {
    public static let version = "1.0.0"
    public static let buildNumber = "1"
    
    /// Initialize the core module with default configuration
    @MainActor
    public static func initialize() {
        print("DeenAssist Core v\(version) (\(buildNumber)) initialized")

        // Initialize feature flags
        _ = IslamicFeatureFlags.shared

        #if DEBUG
        print("🚩 Islamic Feature Flags initialized")
        FeatureFlag.printAllStatuses()
        #endif
    }
    
    /// Create a dependency container for the app
    /// Note: DependencyContainer methods are available in DependencyContainer.swift
    @available(*, deprecated, message: "Use DependencyContainer.shared or direct instantiation instead.")
    public static func createDependencyContainer() {
        fatalError("createDependencyContainer() is deprecated. Use DependencyContainer.shared or instantiate DependencyContainer directly.")
    }
}



// MARK: - Utility Functions

public extension Date {
    /// Check if this date is today
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
    
    /// Check if this date is tomorrow
    var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(self)
    }
    
    /// Get a user-friendly relative date string
    var relativeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - Prayer Times Extensions
// Extensions for PrayerTimes are now defined in PrayerTimes.swift model file

public extension QiblaResult {
    /// Get a user-friendly direction description
    var directionDescription: String {
        return "\(Int(direction))° \(compassBearing)"
    }
    
    /// Check if the direction is accurate (within reasonable bounds)
    var isAccurate: Bool {
        return direction >= 0 && direction <= 360
    }
}
