import Foundation

// MARK: - Account User Model

/// Represents the currently authenticated user
public struct AccountUser: Sendable {
    public let uid: String
    public let email: String?
    
    public init(uid: String, email: String?) {
        self.uid = uid
        self.email = email
    }
}

// MARK: - Settings Snapshot Model

/// Snapshot of user settings for cloud sync
public struct SettingsSnapshot: Codable, Sendable {
    public let calculationMethod: String
    public let madhab: String
    public let timeFormat: String
    public let notificationsEnabled: Bool
    public let notificationOffset: Double
    public let liveActivitiesEnabled: Bool
    public let showArabicSymbolInWidget: Bool
    public let enableIslamicPatterns: Bool
    public let maxLookaheadMonths: Int
    public let useRamadanIshaOffset: Bool
    public let showLongRangePrecision: Bool
    public let userName: String
    public let hasCompletedOnboarding: Bool
    public let settingsVersion: Int
    public let lastSyncDate: Date

    public init(
        calculationMethod: String,
        madhab: String,
        timeFormat: String,
        notificationsEnabled: Bool,
        notificationOffset: Double,
        liveActivitiesEnabled: Bool,
        showArabicSymbolInWidget: Bool,
        enableIslamicPatterns: Bool,
        maxLookaheadMonths: Int,
        useRamadanIshaOffset: Bool,
        showLongRangePrecision: Bool,
        userName: String,
        hasCompletedOnboarding: Bool,
        settingsVersion: Int,
        lastSyncDate: Date
    ) {
        self.calculationMethod = calculationMethod
        self.madhab = madhab
        self.timeFormat = timeFormat
        self.notificationsEnabled = notificationsEnabled
        self.notificationOffset = notificationOffset
        self.liveActivitiesEnabled = liveActivitiesEnabled
        self.showArabicSymbolInWidget = showArabicSymbolInWidget
        self.enableIslamicPatterns = enableIslamicPatterns
        self.maxLookaheadMonths = maxLookaheadMonths
        self.useRamadanIshaOffset = useRamadanIshaOffset
        self.showLongRangePrecision = showLongRangePrecision
        self.userName = userName
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.settingsVersion = settingsVersion
        self.lastSyncDate = lastSyncDate
    }

    // MARK: - Codable Implementation

    private enum CodingKeys: String, CodingKey {
        case calculationMethod, madhab, timeFormat
        case notificationsEnabled, notificationOffset
        case liveActivitiesEnabled, showArabicSymbolInWidget
        case enableIslamicPatterns, maxLookaheadMonths
        case useRamadanIshaOffset, showLongRangePrecision
        case userName, hasCompletedOnboarding
        case settingsVersion, lastSyncDate
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Core required properties (should always exist)
        calculationMethod = try container.decode(String.self, forKey: .calculationMethod)
        madhab = try container.decode(String.self, forKey: .madhab)
        timeFormat = try container.decode(String.self, forKey: .timeFormat)
        settingsVersion = try container.decode(Int.self, forKey: .settingsVersion)
        lastSyncDate = try container.decode(Date.self, forKey: .lastSyncDate)

        // Backward compatible properties (use decodeIfPresent with defaults)
        notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? true
        notificationOffset = try container.decodeIfPresent(Double.self, forKey: .notificationOffset) ?? 300
        liveActivitiesEnabled = try container.decodeIfPresent(Bool.self, forKey: .liveActivitiesEnabled) ?? true
        showArabicSymbolInWidget = try container.decodeIfPresent(Bool.self, forKey: .showArabicSymbolInWidget) ?? true
        enableIslamicPatterns = try container.decodeIfPresent(Bool.self, forKey: .enableIslamicPatterns) ?? false
        maxLookaheadMonths = try container.decodeIfPresent(Int.self, forKey: .maxLookaheadMonths) ?? 60
        useRamadanIshaOffset = try container.decodeIfPresent(Bool.self, forKey: .useRamadanIshaOffset) ?? true
        showLongRangePrecision = try container.decodeIfPresent(Bool.self, forKey: .showLongRangePrecision) ?? false
        userName = try container.decodeIfPresent(String.self, forKey: .userName) ?? ""
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
    }
}

// MARK: - User Account Service Protocol

/// Protocol for managing user accounts and authentication
@MainActor
public protocol UserAccountServiceProtocol: AnyObject {
    
    /// Currently authenticated user
    var currentUser: AccountUser? { get }
    
    /// Send a sign-in link to the provided email address
    /// - Parameter email: Email address to send the link to
    func sendSignInLink(to email: String) async throws
    
    /// Check if a URL is a sign-in link
    /// - Parameter url: URL to check
    /// - Returns: True if the URL is a valid sign-in link
    func isSignInWithEmailLink(_ url: URL) -> Bool
    
    /// Complete sign-in with email link
    /// - Parameters:
    ///   - email: Email address used to request the link
    ///   - linkURL: The sign-in link URL
    func signIn(withEmail email: String, linkURL: URL) async throws
    
    /// Create a new user account with email and password
    /// - Parameters:
    ///   - email: Email address
    ///   - password: Password
    func createUser(email: String, password: String) async throws
    
    /// Sign in with email and password
    /// - Parameters:
    ///   - email: Email address
    ///   - password: Password
    func signIn(email: String, password: String) async throws

    /// Sends a password reset email to the specified address
    /// - Parameter email: The email address that should receive the reset link
    func sendPasswordResetEmail(to email: String) async throws

    /// Confirms a password reset using the provided verification code and updates the password
    /// - Parameters:
    ///   - code: Verification code received by the user
    ///   - newPassword: The new password to set for the account
    func confirmPasswordReset(code: String, newPassword: String) async throws
    
    /// Sign out the current user
    func signOut() async throws
    
    /// Delete the current user's account
    func deleteAccount() async throws
    
    /// Update marketing email opt-in preference
    /// - Parameter enabled: Whether marketing emails are enabled
    func updateMarketingOptIn(_ enabled: Bool) async throws
    
    /// Sync settings snapshot to cloud
    /// - Parameter snapshot: Settings snapshot to sync
    func syncSettingsSnapshot(_ snapshot: SettingsSnapshot) async throws
    
    /// Fetch settings snapshot from cloud
    /// - Returns: Settings snapshot if available
    func fetchSettingsSnapshot() async throws -> SettingsSnapshot?
}

// MARK: - Account Service Errors

public enum AccountServiceError: Error, LocalizedError {
    case notAuthenticated
    case invalidEmail
    case weakPassword
    case emailAlreadyInUse
    case userNotFound
    case wrongPassword
    case networkError
    case requiresRecentLogin
    case unknown(Error)
    
    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return NSLocalizedString(
                "UserAccountError.notAuthenticated",
                comment: "Error shown when a user action requires authentication but no user is signed in"
            )
        case .invalidEmail:
            return NSLocalizedString(
                "UserAccountError.invalidEmail",
                comment: "Error shown when the provided email format is invalid"
            )
        case .weakPassword:
            return NSLocalizedString(
                "UserAccountError.weakPassword",
                comment: "Error shown when a password does not meet minimum strength requirements"
            )
        case .emailAlreadyInUse:
            return NSLocalizedString(
                "UserAccountError.emailAlreadyInUse",
                comment: "Error shown when attempting to register an email that already exists"
            )
        case .userNotFound:
            return NSLocalizedString(
                "UserAccountError.userNotFound",
                comment: "Error shown when no account exists for the supplied email"
            )
        case .wrongPassword:
            return NSLocalizedString(
                "UserAccountError.wrongPassword",
                comment: "Error shown when the provided password is incorrect"
            )
        case .networkError:
            return NSLocalizedString(
                "UserAccountError.networkError",
                comment: "Error shown when a network issue prevents completing the request"
            )
        case .requiresRecentLogin:
            return NSLocalizedString(
                "UserAccountError.requiresRecentLogin",
                comment: "Error shown when a sensitive action requires the user to reauthenticate"
            )
        case .unknown(let error):
            return error.localizedDescription
        }
    }
}
