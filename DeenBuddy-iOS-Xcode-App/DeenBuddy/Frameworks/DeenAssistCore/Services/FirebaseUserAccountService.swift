import Foundation
import FirebaseAuth
import FirebaseFirestore

private typealias FirebaseAuthUser = FirebaseAuth.User

/// Firebase-backed implementation of UserAccountServiceProtocol
@MainActor
public class FirebaseUserAccountService: UserAccountServiceProtocol {
    
    // MARK: - Properties
    
    public private(set) var currentUser: AccountUser?
    
    private let userDefaults = UserDefaults.standard
    private let configurationManager = ConfigurationManager.shared
    
    // Firebase instances
    private let auth: Auth
    private let firestore: Firestore
    
    // MARK: - Cache Keys

    private enum CacheKeys {
        static let pendingEmail = "DeenBuddy.Account.PendingEmail"
        static let marketingOptIn = "DeenBuddy.Account.MarketingOptIn"
    }

    private enum AuthConfiguration {
        static let iosBundleIdentifier = "com.deenbuddy.app"
    }
    
    // MARK: - Initialization
    
    public init() {
        // Initialize Firebase instances
        self.auth = Auth.auth()
        self.firestore = Firestore.firestore()

        // Load current user if authenticated
        loadCurrentUser()
    }
    
    // MARK: - Authentication Methods
    
    public func sendSignInLink(to email: String) async throws {
        guard isValidEmail(email) else {
            throw AccountServiceError.invalidEmail
        }
        
        // Store email for later verification
        userDefaults.set(email, forKey: CacheKeys.pendingEmail)
        
        let actionCodeSettings = ActionCodeSettings()
        actionCodeSettings.url = URL(string: "https://deenbuddy.app/finishSignUp")
        actionCodeSettings.handleCodeInApp = true
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? AuthConfiguration.iosBundleIdentifier
        actionCodeSettings.setIOSBundleID(bundleIdentifier)

        // Note: Dynamic Links is deprecated. For production, consider:
        // - Firebase Hosting with custom domain
        // - Universal Links
        // - Custom email action URL handling

        try await auth.sendSignInLink(toEmail: email, actionCodeSettings: actionCodeSettings)
        
        #if DEBUG
        print("📧 Sign-in link sent to: \(email)")
        #else
        print("📧 Sign-in link sent")
        #endif
    }
    
    public func isSignInWithEmailLink(_ url: URL) -> Bool {
        return auth.isSignIn(withEmailLink: url.absoluteString)
    }
    
    public func signIn(withEmail email: String, linkURL: URL) async throws {
        guard isValidEmail(email) else {
            throw AccountServiceError.invalidEmail
        }
        
        let result = try await auth.signIn(withEmail: email, link: linkURL.absoluteString)
        try await handleSuccessfulSignIn(result.user)

        // Clear pending email
        userDefaults.removeObject(forKey: CacheKeys.pendingEmail)

        #if DEBUG
        print("✅ Signed in with email link: \(email)")
        #else
        print("✅ Signed in with email link")
        #endif
    }
    
    public func createUser(email: String, password: String) async throws {
        guard isValidEmail(email) else {
            throw AccountServiceError.invalidEmail
        }
        
        guard password.count >= 6 else {
            throw AccountServiceError.weakPassword
        }
        
        do {
            let result = try await auth.createUser(withEmail: email, password: password)
            try await handleSuccessfulSignIn(result.user)
        } catch let error as NSError {
            throw mapFirebaseError(error)
        }

        #if DEBUG
        print("✅ Created user account: \(email)")
        #else
        print("✅ Created user account")
        #endif
    }
    
    public func signIn(email: String, password: String) async throws {
        guard isValidEmail(email) else {
            throw AccountServiceError.invalidEmail
        }
        
        do {
            let result = try await auth.signIn(withEmail: email, password: password)
            try await handleSuccessfulSignIn(result.user)
        } catch let error as NSError {
            throw mapFirebaseError(error)
        }

        #if DEBUG
        print("✅ Signed in with password: \(email)")
        #else
        print("✅ Signed in with password")
        #endif
    }

    public func sendPasswordResetEmail(to email: String) async throws {
        guard isValidEmail(email) else {
            throw AccountServiceError.invalidEmail
        }

        do {
            try await auth.sendPasswordReset(withEmail: email)
            #if DEBUG
            print("📧 Password reset email sent to: \(email)")
            #else
            print("📧 Password reset email sent")
            #endif
        } catch let error as NSError {
            throw mapFirebaseError(error)
        }
    }

    public func confirmPasswordReset(code: String, newPassword: String) async throws {
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCode.isEmpty else {
            throw AccountServiceError.unknown(
                NSError(
                    domain: "FirebaseUserAccountService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Reset code is missing"]
                )
            )
        }
        
        guard newPassword.count >= 6 else {
            throw AccountServiceError.weakPassword
        }

        do {
            try await auth.confirmPasswordReset(withCode: trimmedCode, newPassword: newPassword)
            #if DEBUG
            print("🔐 Password reset confirmed for code: \(trimmedCode.prefix(4))***")
            #else
            print("🔐 Password reset confirmed")
            #endif
        } catch let error as NSError {
            throw mapFirebaseError(error)
        }
    }
    
    public func signOut() async throws {
        try auth.signOut()

        currentUser = nil
        print("👋 Signed out")
    }
    
    public func deleteAccount() async throws {
        guard let firebaseUser = auth.currentUser else {
            throw AccountServiceError.notAuthenticated
        }

        if let cachedUser = currentUser, cachedUser.uid != firebaseUser.uid {
            throw AccountServiceError.notAuthenticated
        }

        let uid = firebaseUser.uid

        // Delete the Firebase auth user first; if this fails (e.g., requires re-auth), abort
        do {
            try await firebaseUser.delete()
        } catch let error as NSError {
            if error.code == AuthErrorCode.requiresRecentLogin.rawValue {
                throw AccountServiceError.requiresRecentLogin
            }
            throw mapFirebaseError(error)
        }

        // Delete Firestore data after auth account removal succeeds
        try await firestore.collection("users").document(uid).collection("profile").document("info").delete()
        try await firestore.collection("users").document(uid).collection("settings").document("current").delete()
        try await firestore.collection("users").document(uid).delete()

        // Clear cached account data after both deletions succeed
        userDefaults.removeObject(forKey: CacheKeys.pendingEmail)
        userDefaults.removeObject(forKey: CacheKeys.marketingOptIn)

        currentUser = nil
        print("🗑️ Account deleted")
    }
    
    // MARK: - Profile Methods
    
    public func updateMarketingOptIn(_ enabled: Bool) async throws {
        guard let user = currentUser else {
            throw AccountServiceError.notAuthenticated
        }
        
        // Cache locally
        userDefaults.set(enabled, forKey: CacheKeys.marketingOptIn)
        
        do {
            try await firestore.collection("users").document(user.uid).collection("profile").document("info").setData([
                "marketingOptIn": enabled,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
        } catch {
            print("⚠️ Failed to update marketing opt-in: \(error)")
            throw AccountServiceError.unknown(error)
        }
        
        print("📧 Marketing opt-in updated: \(enabled)")
    }
    
    // MARK: - Settings Sync Methods
    
    public func syncSettingsSnapshot(_ snapshot: SettingsSnapshot) async throws {
        guard let user = currentUser else {
            throw AccountServiceError.notAuthenticated
        }
        
        let data: [String: Any] = [
            "calculationMethod": snapshot.calculationMethod,
            "madhab": snapshot.madhab,
            "timeFormat": snapshot.timeFormat,
            "notificationsEnabled": snapshot.notificationsEnabled,
            "notificationOffset": snapshot.notificationOffset,
            "liveActivitiesEnabled": snapshot.liveActivitiesEnabled,
            "showArabicSymbolInWidget": snapshot.showArabicSymbolInWidget,
            "enableIslamicPatterns": snapshot.enableIslamicPatterns,
            "userName": snapshot.userName,
            "hasCompletedOnboarding": snapshot.hasCompletedOnboarding,
            "settingsVersion": snapshot.settingsVersion,
            "lastSyncDate": Timestamp(date: snapshot.lastSyncDate)
        ]
        
        do {
            try await firestore
                .collection("users")
                .document(user.uid)
                .collection("settings")
                .document("current")
                .setData(data, merge: true)
            
            #if DEBUG
            print("☁️ Settings synced to cloud for user: \(user.uid)")
            #else
            print("☁️ Settings synced to cloud")
            #endif
        } catch {
            throw AccountServiceError.unknown(error)
        }
    }
    
    public func fetchSettingsSnapshot() async throws -> SettingsSnapshot? {
        guard let user = currentUser else {
            throw AccountServiceError.notAuthenticated
        }
        
        do {
            let doc = try await firestore
                .collection("users")
                .document(user.uid)
                .collection("settings")
                .document("current")
                .getDocument()
            
            guard doc.exists, let data = doc.data() else {
                return nil
            }
            
            let snapshot = SettingsSnapshot(
                calculationMethod: data["calculationMethod"] as? String ?? "muslimWorldLeague",
                madhab: data["madhab"] as? String ?? "shafi",
                timeFormat: data["timeFormat"] as? String ?? "12",
                notificationsEnabled: data["notificationsEnabled"] as? Bool ?? true,
                notificationOffset: data["notificationOffset"] as? Double ?? 300,
                liveActivitiesEnabled: data["liveActivitiesEnabled"] as? Bool ?? true,
                showArabicSymbolInWidget: data["showArabicSymbolInWidget"] as? Bool ?? true,
                enableIslamicPatterns: data["enableIslamicPatterns"] as? Bool ?? false,
                userName: data["userName"] as? String ?? "",
                hasCompletedOnboarding: data["hasCompletedOnboarding"] as? Bool ?? false,
                settingsVersion: data["settingsVersion"] as? Int ?? 1,
                lastSyncDate: (data["lastSyncDate"] as? Timestamp)?.dateValue() ?? Date()
            )
            
            #if DEBUG
            print("☁️ Settings fetched from cloud for user: \(user.uid)")
            #else
            print("☁️ Settings fetched from cloud")
            #endif
            return snapshot
        } catch {
            throw AccountServiceError.unknown(error)
        }
    }
    
    // MARK: - Private Helpers

    private func loadCurrentUser() {
        if let firebaseUser = auth.currentUser {
            currentUser = AccountUser(
                uid: firebaseUser.uid,
                email: firebaseUser.email
            )
            #if DEBUG
            print("👤 Loaded current user: \(firebaseUser.email ?? "unknown")")
            #else
            print("👤 Loaded current user")
            #endif
        }
    }
    
    private func handleSuccessfulSignIn(_ firebaseUser: FirebaseAuthUser) async throws {
        currentUser = AccountUser(
            uid: firebaseUser.uid,
            email: firebaseUser.email
        )

        // Create or update profile document
        let profileData: [String: Any] = [
            "email": firebaseUser.email ?? "",
            "createdAt": FieldValue.serverTimestamp(),
            "lastLoginAt": FieldValue.serverTimestamp(),
            "marketingOptIn": userDefaults.bool(forKey: CacheKeys.marketingOptIn)
        ]

        do {
            try await firestore
                .collection("users")
                .document(firebaseUser.uid)
                .collection("profile")
                .document("info")
                .setData(profileData, merge: true)
        } catch {
            print("⚠️ Failed to create/update user profile: \(error)")
            throw AccountServiceError.unknown(error)
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func mapFirebaseError(_ error: NSError) -> AccountServiceError {
        switch error.code {
        case AuthErrorCode.emailAlreadyInUse.rawValue:
            return .emailAlreadyInUse
        case AuthErrorCode.userNotFound.rawValue:
            return .userNotFound
        case AuthErrorCode.wrongPassword.rawValue:
            return .wrongPassword
        case AuthErrorCode.networkError.rawValue:
            return .networkError
        case AuthErrorCode.invalidEmail.rawValue:
            return .invalidEmail
        case AuthErrorCode.weakPassword.rawValue:
            return .weakPassword
        case AuthErrorCode.requiresRecentLogin.rawValue:
            return .requiresRecentLogin
        default:
            return .unknown(error)
        }
    }
}
