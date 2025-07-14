import Foundation
import Security

// MARK: - Configuration Structures

public struct SupabaseConfiguration {
    public let url: String
    public let anonKey: String
    
    public init(url: String, anonKey: String) {
        self.url = url
        self.anonKey = anonKey
    }
}

/// Configuration manager for secure app configuration
@MainActor
public class ConfigurationManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var currentEnvironment: AppEnvironment = .development
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
    
    /// Store initial configuration credentials (for development setup only)
    public func storeInitialCredentials(supabaseUrl: String, anonKey: String, environment: AppEnvironment) throws {
        let urlKey = "SUPABASE_URL_\(environment.rawValue.uppercased())"
        let keyKey = "SUPABASE_ANON_KEY_\(environment.rawValue.uppercased())"
        
        // Validate credentials before storing
        try validateCredentials(url: supabaseUrl, key: anonKey)
        
        try storeSecureValue(supabaseUrl, for: urlKey)
        try storeSecureValue(anonKey, for: keyKey)
        
        print("✅ Stored credentials for \(environment.rawValue) environment")
    }
    
    /// Delete stored credentials for an environment
    public func deleteCredentials(for environment: AppEnvironment) throws {
        let urlKey = "SUPABASE_URL_\(environment.rawValue.uppercased())"
        let keyKey = "SUPABASE_ANON_KEY_\(environment.rawValue.uppercased())"
        
        try keychain.delete(for: urlKey)
        try keychain.delete(for: keyKey)
        
        print("🗑️ Deleted credentials for \(environment.rawValue) environment")
    }
    
    /// Check if credentials exist for an environment
    public func hasCredentials(for environment: AppEnvironment) -> Bool {
        let urlKey = "SUPABASE_URL_\(environment.rawValue.uppercased())"
        let keyKey = "SUPABASE_ANON_KEY_\(environment.rawValue.uppercased())"
        
        return keychain.exists(for: urlKey) && keychain.exists(for: keyKey)
    }
    
    /// Validate credential format
    private func validateCredentials(url: String, key: String) throws {
        // Basic URL validation
        guard url.hasPrefix("https://") && url.contains("supabase") else {
            throw ConfigurationError.credentialValidationFailed
        }
        
        // Basic JWT token validation (should start with eyJ)
        guard key.hasPrefix("eyJ") && key.split(separator: ".").count == 3 else {
            throw ConfigurationError.credentialValidationFailed
        }
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
    
    /// Force reload configuration (useful after credential updates)
    public func reloadConfiguration() {
        loadConfiguration()
    }
    
    /// Get configuration status for debugging
    public func getConfigurationStatus() -> String {
        var status = "Configuration Status:\n"
        status += "Environment: \(currentEnvironment.rawValue)\n"
        status += "Configured: \(isConfigured)\n"
        
        for env in AppEnvironment.allCases {
            let hasCredentials = hasCredentials(for: env)
            status += "\(env.rawValue): \(hasCredentials ? "✅" : "❌")\n"
        }
        
        return status
    }
    
    // MARK: - Private Methods
    
    private func detectEnvironment() -> AppEnvironment {
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
    
    private func loadConfigurationForEnvironment(_ environment: AppEnvironment) throws -> AppConfiguration {
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
        // SECURITY: Credentials must be stored in keychain before first run
        // Use environment variables or secure configuration during development
        guard let supabaseUrl = getSecureValue(for: "SUPABASE_URL_DEV"),
              let anonKey = getSecureValue(for: "SUPABASE_ANON_KEY_DEV") else {
            throw ConfigurationError.missingRequiredKeys
        }

        return AppConfiguration(
            environment: .development,
            supabase: SupabaseConfiguration(
                url: supabaseUrl,
                anonKey: anonKey
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
        // SECURITY: Production credentials must be stored in keychain before deployment
        // Never include production credentials in source code
        guard let supabaseUrl = getSecureValue(for: "SUPABASE_URL_PROD"),
              let anonKey = getSecureValue(for: "SUPABASE_ANON_KEY_PROD") else {
            throw ConfigurationError.missingRequiredKeys
        }
        
        return AppConfiguration(
            environment: .production,
            supabase: SupabaseConfiguration(
                url: supabaseUrl,
                anonKey: anonKey
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
    public let environment: AppEnvironment
    public let supabase: SupabaseConfiguration
    public let api: APIConfiguration
    public let features: FeatureFlags
    public let logging: LoggingConfiguration
    
    public init(
        environment: AppEnvironment,
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

public enum AppEnvironment: String, CaseIterable {
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
        guard let data = value.data(using: .utf8) else {
            throw ConfigurationError.invalidConfiguration
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            print("❌ Keychain store failed for key '\(key)' with status: \(status)")
            throw ConfigurationError.keychainError(status)
        }
        
        print("✅ Securely stored credential in keychain for key: \(key)")
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
        
        guard status == errSecSuccess else {
            if status != errSecItemNotFound {
                print("❌ Keychain retrieve failed for key '\(key)' with status: \(status)")
            }
            return nil
        }
        
        guard let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            print("❌ Keychain data corruption for key '\(key)'")
            return nil
        }
        
        return string
    }
    
    func delete(for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ConfigurationError.keychainError(status)
        }
        
        print("🗑️ Deleted credential from keychain for key: \(key)")
    }
    
    func exists(for key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
}

// MARK: - Error Types

public enum ConfigurationError: LocalizedError {
    case missingRequiredKeys
    case invalidConfiguration
    case keychainError(OSStatus)
    case environmentNotSupported
    case credentialValidationFailed
    
    public var errorDescription: String? {
        switch self {
        case .missingRequiredKeys:
            return "Required configuration keys are missing from keychain. Please run initial setup."
        case .invalidConfiguration:
            return "Configuration data is invalid or corrupted."
        case .keychainError(let status):
            return "Keychain error: \(status) - \(keychainErrorDescription(status))"
        case .environmentNotSupported:
            return "Current environment is not supported for this operation."
        case .credentialValidationFailed:
            return "Credential validation failed. Please check your configuration."
        }
    }
    
    private func keychainErrorDescription(_ status: OSStatus) -> String {
        switch status {
        case errSecItemNotFound:
            return "Item not found in keychain"
        case errSecDuplicateItem:
            return "Duplicate item in keychain"
        case errSecAuthFailed:
            return "Authentication failed"
        case errSecNotAvailable:
            return "Keychain not available"
        case errSecParam:
            return "Invalid parameter"
        case errSecAllocate:
            return "Memory allocation failed"
        case errSecUserCanceled:
            return "User canceled operation"
        case errSecBadReq:
            return "Bad request"
        case errSecInternalError:
            return "Internal keychain error"
        case errSecNoDefaultKeychain:
            return "No default keychain available"
        case errSecReadOnlyAttr:
            return "Read-only attribute"
        case errSecWrongSecVersion:
            return "Wrong security version"
        case errSecKeySizeNotAllowed:
            return "Key size not allowed"
        case errSecNoStorageModule:
            return "No storage module available"
        case errSecNoCertificateModule:
            return "No certificate module available"
        case errSecNoPolicyModule:
            return "No policy module available"
        case errSecInteractionNotAllowed:
            return "Interaction not allowed"
        case errSecDataNotAvailable:
            return "Data not available"
        case errSecDataNotModifiable:
            return "Data not modifiable"
        default:
            return "Unknown keychain error"
        }
    }
}
