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

// MARK: - Usage Instructions
/*
 This file allows the main iOS app to import DeenAssistCore and automatically
 get access to all package dependencies without needing separate imports.
 
 In your iOS app, simply use:
 ```swift
 import DeenAssistCore
 
 // Now you have access to:
 // - Adhan prayer time calculations
 ```
 
 Instead of needing multiple imports:
 ```swift
 import DeenAssistCore
 import Adhan
 ```
*/
