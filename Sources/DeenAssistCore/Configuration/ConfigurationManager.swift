import Foundation
import Security

/// Configuration manager for secure app configuration
@MainActor
public class ConfigurationManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var currentEnvironment: Environment = .development
    @Published public var isConfigured = false
    
    // MARK: - Private Properties
    
    private let keychain = KeychainManager()
    private var configuration: AppConfiguration?
    
    // MARK: - Singleton
    
    public static let shared = ConfigurationManager()
    
    private init() {
        loadConfiguration()
    }
    
    // MARK: - Public Methods
    
    /// Load configuration for the current environment
    public func loadConfiguration() {
        currentEnvironment = detectEnvironment()
        
        do {
            configuration = try loadConfigurationForEnvironment(currentEnvironment)
            isConfigured = true
            print("Configuration loaded for environment: \(currentEnvironment)")
        } catch {
            print("Failed to load configuration: \(error)")
            isConfigured = false
        }
    }
    
    /// Get Supabase configuration
    public func getSupabaseConfiguration() -> SupabaseConfiguration? {
        guard let config = configuration else { return nil }
        return config.supabase
    }
    
    /// Get API configuration
    public func getAPIConfiguration() -> APIConfiguration? {
        guard let config = configuration else { return nil }
        return config.api
    }
    
    /// Get app configuration
    public func getAppConfiguration() -> AppConfiguration? {
        return configuration
    }
    
    /// Store sensitive configuration in keychain
    public func storeSecureValue(_ value: String, for key: String) throws {
        try keychain.store(value: value, for: key)
    }
    
    /// Retrieve sensitive configuration from keychain
    public func getSecureValue(for key: String) -> String? {
        return keychain.retrieve(for: key)
    }
    
    /// Update configuration for testing
    public func setTestConfiguration(_ config: AppConfiguration) {
        self.configuration = config
        self.currentEnvironment = .testing
        self.isConfigured = true
    }
    
    // MARK: - Private Methods
    
    private func detectEnvironment() -> Environment {
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return .testing
        } else {
            return .development
        }
        #else
        return .production
        #endif
    }
    
    private func loadConfigurationForEnvironment(_ environment: Environment) throws -> AppConfiguration {
        switch environment {
        case .development:
            return try loadDevelopmentConfiguration()
        case .staging:
            return try loadStagingConfiguration()
        case .production:
            return try loadProductionConfiguration()
        case .testing:
            return try loadTestingConfiguration()
        }
    }
    
    private func loadDevelopmentConfiguration() throws -> AppConfiguration {
        // Store the actual Supabase keys securely if not already stored
        let supabaseUrl = "https://hjgwbkcjjclwqamtmhsa.supabase.co"
        let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhqZ3dia2NqamNsd3FhbXRtaHNhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE1NzQwOTYsImV4cCI6MjA2NzE1MDA5Nn0.pipfeKNNDclXlfOimWQnhkf_VY-YTsV3_vZaoEbWSGM"

        // Store in keychain if not already present
        if getSecureValue(for: "SUPABASE_URL_DEV") == nil {
            setSecureValue(supabaseUrl, for: "SUPABASE_URL_DEV")
        }
        if getSecureValue(for: "SUPABASE_ANON_KEY_DEV") == nil {
            setSecureValue(anonKey, for: "SUPABASE_ANON_KEY_DEV")
        }

        return AppConfiguration(
            environment: .development,
            supabase: SupabaseConfiguration(
                url: getSecureValue(for: "SUPABASE_URL_DEV") ?? supabaseUrl,
                anonKey: getSecureValue(for: "SUPABASE_ANON_KEY_DEV") ?? anonKey
            ),
            api: APIConfiguration(
                baseURL: "https://api.aladhan.com/v1",
                timeout: 30,
                maxRetries: 3,
                rateLimitPerMinute: 90
            ),
            features: FeatureFlags(
                enableAnalytics: false,
                enableCrashReporting: false,
                enableBetaFeatures: true,
                enableOfflineMode: true
            ),
            logging: LoggingConfiguration(
                level: .debug,
                enableFileLogging: true,
                enableRemoteLogging: false
            )
        )
    }
    
    private func loadStagingConfiguration() throws -> AppConfiguration {
        return AppConfiguration(
            environment: .staging,
            supabase: SupabaseConfiguration(
                url: getSecureValue(for: "SUPABASE_URL_STAGING") ?? "",
                anonKey: getSecureValue(for: "SUPABASE_ANON_KEY_STAGING") ?? ""
            ),
            api: APIConfiguration(
                baseURL: "https://api.aladhan.com/v1",
                timeout: 30,
                maxRetries: 3,
                rateLimitPerMinute: 90
            ),
            features: FeatureFlags(
                enableAnalytics: true,
                enableCrashReporting: true,
                enableBetaFeatures: true,
                enableOfflineMode: true
            ),
            logging: LoggingConfiguration(
                level: .info,
                enableFileLogging: true,
                enableRemoteLogging: true
            )
        )
    }
    
    private func loadProductionConfiguration() throws -> AppConfiguration {
        // Use the same Supabase keys for production (they're already production keys)
        let supabaseUrl = "https://hjgwbkcjjclwqamtmhsa.supabase.co"
        let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhqZ3dia2NqamNsd3FhbXRtaHNhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE1NzQwOTYsImV4cCI6MjA2NzE1MDA5Nn0.pipfeKNNDclXlfOimWQnhkf_VY-YTsV3_vZaoEbWSGM"

        // Store in keychain if not already present
        if getSecureValue(for: "SUPABASE_URL_PROD") == nil {
            setSecureValue(supabaseUrl, for: "SUPABASE_URL_PROD")
        }
        if getSecureValue(for: "SUPABASE_ANON_KEY_PROD") == nil {
            setSecureValue(anonKey, for: "SUPABASE_ANON_KEY_PROD")
        }

        let supabaseURL = getSecureValue(for: "SUPABASE_URL_PROD") ?? supabaseUrl
        let supabaseKey = getSecureValue(for: "SUPABASE_ANON_KEY_PROD") ?? anonKey
        
        return AppConfiguration(
            environment: .production,
            supabase: SupabaseConfiguration(
                url: supabaseURL,
                anonKey: supabaseKey
            ),
            api: APIConfiguration(
                baseURL: "https://api.aladhan.com/v1",
                timeout: 30,
                maxRetries: 3,
                rateLimitPerMinute: 90
            ),
            features: FeatureFlags(
                enableAnalytics: true,
                enableCrashReporting: true,
                enableBetaFeatures: false,
                enableOfflineMode: true
            ),
            logging: LoggingConfiguration(
                level: .warning,
                enableFileLogging: false,
                enableRemoteLogging: true
            )
        )
    }
    
    private func loadTestingConfiguration() throws -> AppConfiguration {
        return AppConfiguration(
            environment: .testing,
            supabase: SupabaseConfiguration(
                url: "https://test.supabase.co",
                anonKey: "test-key"
            ),
            api: APIConfiguration(
                baseURL: "https://api.aladhan.com/v1",
                timeout: 10,
                maxRetries: 1,
                rateLimitPerMinute: 1000
            ),
            features: FeatureFlags(
                enableAnalytics: false,
                enableCrashReporting: false,
                enableBetaFeatures: true,
                enableOfflineMode: true
            ),
            logging: LoggingConfiguration(
                level: .debug,
                enableFileLogging: false,
                enableRemoteLogging: false
            )
        )
    }
}

// MARK: - Configuration Models

public struct AppConfiguration {
    public let environment: Environment
    public let supabase: SupabaseConfiguration
    public let api: APIConfiguration
    public let features: FeatureFlags
    public let logging: LoggingConfiguration
    
    public init(
        environment: Environment,
        supabase: SupabaseConfiguration,
        api: APIConfiguration,
        features: FeatureFlags,
        logging: LoggingConfiguration
    ) {
        self.environment = environment
        self.supabase = supabase
        self.api = api
        self.features = features
        self.logging = logging
    }
}

public enum Environment: String, CaseIterable {
    case development = "development"
    case staging = "staging"
    case production = "production"
    case testing = "testing"
    
    public var displayName: String {
        return rawValue.capitalized
    }
}

public struct FeatureFlags {
    public let enableAnalytics: Bool
    public let enableCrashReporting: Bool
    public let enableBetaFeatures: Bool
    public let enableOfflineMode: Bool
    
    public init(
        enableAnalytics: Bool,
        enableCrashReporting: Bool,
        enableBetaFeatures: Bool,
        enableOfflineMode: Bool
    ) {
        self.enableAnalytics = enableAnalytics
        self.enableCrashReporting = enableCrashReporting
        self.enableBetaFeatures = enableBetaFeatures
        self.enableOfflineMode = enableOfflineMode
    }
}

public struct LoggingConfiguration {
    public let level: LogLevel
    public let enableFileLogging: Bool
    public let enableRemoteLogging: Bool
    
    public init(level: LogLevel, enableFileLogging: Bool, enableRemoteLogging: Bool) {
        self.level = level
        self.enableFileLogging = enableFileLogging
        self.enableRemoteLogging = enableRemoteLogging
    }
    
    public enum LogLevel: String, CaseIterable {
        case debug = "debug"
        case info = "info"
        case warning = "warning"
        case error = "error"
        
        public var displayName: String {
            return rawValue.capitalized
        }
    }
}

// MARK: - Keychain Manager

private class KeychainManager {
    private let service = "com.deenassist.app"
    
    func store(value: String, for key: String) throws {
        let data = value.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw ConfigurationError.keychainError(status)
        }
    }
    
    func retrieve(for key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return string
    }
}

// MARK: - Error Types

public enum ConfigurationError: LocalizedError {
    case missingRequiredKeys
    case invalidConfiguration
    case keychainError(OSStatus)
    case environmentNotSupported
    
    public var errorDescription: String? {
        switch self {
        case .missingRequiredKeys:
            return "Required configuration keys are missing"
        case .invalidConfiguration:
            return "Configuration is invalid"
        case .keychainError(let status):
            return "Keychain error: \(status)"
        case .environmentNotSupported:
            return "Environment is not supported"
        }
    }
}
