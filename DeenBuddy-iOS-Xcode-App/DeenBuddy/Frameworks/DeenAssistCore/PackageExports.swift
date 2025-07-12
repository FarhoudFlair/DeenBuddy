//
//  PackageExports.swift
//  DeenAssistCore
//
//  Package integration helper for iOS app
//  This file re-exports all package dependencies to make imports easier
//

// MARK: - Package Dependencies Re-exports

/// Adhan Swift library for Islamic prayer time calculations
/// Provides accurate prayer times based on location and calculation methods
@_exported import Adhan

// MARK: - Core Exports

/// Islamic Feature Flags System
/// Provides safe rollout and rollback capabilities for new Islamic features
@_exported import Foundation

// MARK: - Feature Flag Public API

/// Main feature flag system for Islamic features
// NOTE: Configuration types are available directly from their respective modules
// - IslamicFeatureFlags from IslamicFeatureFlags.swift
// - IslamicFeature from IslamicFeatureFlags.swift
// - FeatureFlag from IslamicFeatureFlags.swift

// MARK: - Usage Instructions
/*
 This file allows the main iOS app to import DeenAssistCore and automatically
 get access to all package dependencies without needing separate imports.
 
 In your iOS app, simply use:
 ```swift
 import DeenAssistCore
 
 // Now you have access to:
 // - Adhan prayer time calculations
 // - Islamic feature flags system
 // - All core services and models
 
 // Check feature flags:
 if FeatureFlag.enhancedPrayerTracking {
     // Show enhanced prayer tracking UI
 }
 
 // Or use the detailed API:
 if FeatureFlag.isEnabled(.digitalTasbih) {
     // Show digital tasbih feature
 }
 ```
 
 Instead of needing multiple imports:
 ```swift
 import DeenAssistCore
 import Adhan
 ```
*/
