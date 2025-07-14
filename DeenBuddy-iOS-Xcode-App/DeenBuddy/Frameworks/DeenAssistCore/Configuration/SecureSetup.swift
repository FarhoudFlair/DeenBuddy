import Foundation

/// Secure setup utility for initial credential configuration
/// This should only be used during development setup and removed from production builds
public class SecureSetup {
    
    private let configManager = ConfigurationManager.shared
    
    /// Setup development credentials
    /// WARNING: This should only be used during development setup
    /// Remove this method before production deployment
    public func setupDevelopmentCredentials() throws {
        #if DEBUG
        // These are example credentials - replace with your actual development credentials
        let devUrl = ProcessInfo.processInfo.environment["SUPABASE_URL_DEV"] ?? ""
        let devKey = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY_DEV"] ?? ""
        
        guard !devUrl.isEmpty && !devKey.isEmpty else {
            throw ConfigurationError.missingRequiredKeys
        }
        
        try configManager.storeInitialCredentials(
            supabaseUrl: devUrl,
            anonKey: devKey,
            environment: .development
        )
        
        print("✅ Development credentials configured from environment variables")
        #else
        throw ConfigurationError.environmentNotSupported
        #endif
    }
    
    /// Setup production credentials
    /// WARNING: This should only be used during secure deployment setup
    /// Credentials should be injected via CI/CD pipeline or secure deployment process
    public func setupProductionCredentials() throws {
        #if DEBUG
        print("⚠️  WARNING: Production credential setup should not be used in debug builds")
        #endif
        
        let prodUrl = ProcessInfo.processInfo.environment["SUPABASE_URL_PROD"] ?? ""
        let prodKey = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY_PROD"] ?? ""
        
        guard !prodUrl.isEmpty && !prodKey.isEmpty else {
            throw ConfigurationError.missingRequiredKeys
        }
        
        try configManager.storeInitialCredentials(
            supabaseUrl: prodUrl,
            anonKey: prodKey,
            environment: .production
        )
        
        print("✅ Production credentials configured from environment variables")
    }
    
    /// Verify that required credentials are present for an environment
    public func verifyCredentials(for environment: AppEnvironment) -> Bool {
        return configManager.hasCredentials(for: environment)
    }
    
    /// Clear all stored credentials (for testing or security purposes)
    public func clearAllCredentials() throws {
        let environments: [AppEnvironment] = [.development, .staging, .production]
        
        for env in environments {
            do {
                try configManager.deleteCredentials(for: env)
            } catch {
                print("⚠️ Failed to clear credentials for \(env.rawValue): \(error)")
            }
        }
        
        print("🗑️ Credential cleanup completed")
    }
}

// MARK: - Development Helper Extension

#if DEBUG
extension SecureSetup {
    /// Helper for quick development setup with console output
    public func quickDevelopmentSetup() {
        print("🔐 Setting up development credentials...")
        
        do {
            try setupDevelopmentCredentials()
            
            if verifyCredentials(for: .development) {
                print("✅ Development environment is ready")
                configManager.reloadConfiguration()
            } else {
                print("❌ Development credential verification failed")
            }
            
        } catch {
            print("❌ Development setup failed: \(error)")
            print("💡 Make sure to set SUPABASE_URL_DEV and SUPABASE_ANON_KEY_DEV environment variables")
        }
    }
    
    /// Display configuration status for debugging
    public func displayConfigurationStatus() {
        print(configManager.getConfigurationStatus())
    }
    
    /// Reset and setup fresh credentials
    public func resetAndSetup(for environment: AppEnvironment) throws {
        print("🔄 Resetting credentials for \(environment.rawValue) environment...")
        
        // Clear existing credentials
        try configManager.deleteCredentials(for: environment)
        
        // Setup new credentials based on environment
        switch environment {
        case .development:
            try setupDevelopmentCredentials()
        case .production:
            try setupProductionCredentials()
        case .staging:
            throw ConfigurationError.environmentNotSupported
        case .testing:
            // Testing credentials don't need keychain storage
            break
        }
        
        configManager.reloadConfiguration()
        print("✅ \(environment.rawValue) credentials reset and configured")
    }
}
#endif