//
//  PackageExports.swift
//  DeenBuddyCore
//
//  Package integration helper for iOS app
//  This file re-exports all package dependencies to make imports easier
//

// MARK: - Package Dependencies Re-exports

/// Supabase Swift SDK for backend integration
/// Provides database, authentication, and real-time functionality
@_exported import Supabase

/// Adhan Swift library for Islamic prayer time calculations
/// Provides accurate prayer times based on location and calculation methods
@_exported import Adhan

/// The Composable Architecture for state management
/// Provides unidirectional data flow and composable app architecture
@_exported import ComposableArchitecture

// MARK: - Usage Instructions
/*
 This file allows the main iOS app to import DeenBuddyCore and automatically
 get access to all package dependencies without needing separate imports.
 
 In your iOS app, simply use:
 ```swift
 import DeenBuddyCore
 
 // Now you have access to:
 // - Supabase client and types
 // - Adhan prayer time calculations
 // - ComposableArchitecture Store, Reducer, etc.
 ```
 
 Instead of needing multiple imports:
 ```swift
 import DeenBuddyCore
 import Supabase
 import Adhan
 import ComposableArchitecture
 ```
*/
