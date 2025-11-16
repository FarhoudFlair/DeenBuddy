import Foundation
import FirebaseCore

/// Handles Firebase initialization with safety guards for testing
public class FirebaseInitializer {
    
    private static var isConfigured = false
    private static let lock = NSLock()
    
    /// Configure Firebase if not already configured
    /// Safe to call multiple times - will only configure once
    public static func configureIfNeeded() {
        lock.lock()
        defer { lock.unlock()}
        
        guard !isConfigured else {
            print("🔥 Firebase already configured, skipping")
            return
        }
        
        // Skip Firebase configuration in test environment
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            print("🧪 Test environment detected, skipping Firebase configuration")
            return
        }
        #endif
        
        FirebaseApp.configure()
        isConfigured = true
        print("🔥 Firebase configured successfully")
    }
    
    /// Reset configuration state (for testing purposes only)
    public static func resetForTesting() {
        lock.lock()
        defer { lock.unlock() }
        isConfigured = false
    }
}

