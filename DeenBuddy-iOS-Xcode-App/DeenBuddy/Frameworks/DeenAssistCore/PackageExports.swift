//
//  PackageExports.swift
//  DeenAssistCore
//
//  Package integration helper for iOS app
//  This file centralizes package imports and documents intentional public exports
//

// MARK: - Package Dependencies Imports

/// Adhan Swift library for Islamic prayer time calculations
/// Provides accurate prayer times based on location and calculation methods
import Adhan

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
 This file documents how the main iOS app gains access to DeenAssistCore package
 dependencies and which external symbols are intentionally surfaced.
 
 In your iOS app, simply use:
 ```swift
 import DeenAssistCore
 
 // Now you have access to:
 // - Islamic feature flags system
 // - All core services and models
 // - Explicit Adhan helper typealiases (see bottom of this file)
 
 // Check feature flags:
 if FeatureFlag.enhancedPrayerTracking {
     // Show enhanced prayer tracking UI
 }
 
 // Or use the detailed API:
 if FeatureFlag.isEnabled(.digitalTasbih) {
     // Show digital tasbih feature
 }
 ```
 
 When you need the full Adhan API, add an explicit import:
 ```swift
 import DeenAssistCore
 import Adhan
 ```
*/

// MARK: - Explicit Adhan Public API

/// Minimal, opt-in Adhan surface area that DeenAssistCore intentionally exposes.
/// Clients needing broader Adhan access should import Adhan directly.
public typealias AdhanCalculationMethod = Adhan.CalculationMethod
public typealias AdhanCalculationParameters = Adhan.CalculationParameters
public typealias AdhanCoordinates = Adhan.Coordinates
public typealias AdhanMadhab = Adhan.Madhab
public typealias AdhanPrayerTimes = Adhan.PrayerTimes
