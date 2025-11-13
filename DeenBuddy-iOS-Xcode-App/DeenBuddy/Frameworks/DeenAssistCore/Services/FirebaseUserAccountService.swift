import Foundation
// NOTE: Firebase imports will be added when SPM packages are installed
// import FirebaseAuth
// import FirebaseFirestore

/// Firebase-backed implementation of UserAccountServiceProtocol
@MainActor
public class FirebaseUserAccountService: UserAccountServiceProtocol {
    
    // MARK: - Properties
    
    public private(set) var currentUser: AccountUser?
    
    private let userDefaults = UserDefaults.standard
    private let configurationManager = ConfigurationManager.shared
    
    // Firebase instances (will be initialized when Firebase is added)
    // private let auth: Auth
    // private let firestore: Firestore
    
    // MARK: - Cache Keys
    
    private enum CacheKeys {
        static let pendingEmail = "DeenBuddy.Account.PendingEmail"
        static let marketingOptIn = "DeenBuddy.Account.MarketingOptIn"
    }
    
    // MARK: - Initialization
    
    public init() {
        // Initialize Firebase instances when available
        // self.auth = Auth.auth()
        // self.firestore = Firestore.firestore()
        
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
        
        // TODO: Implement when Firebase is added
        // let actionCodeSettings = ActionCodeSettings()
        // actionCodeSettings.url = URL(string: "https://deenbuddy.app/finishSignUp")
        // actionCodeSettings.handleCodeInApp = true
        // actionCodeSettings.setIOSBundleID(Bundle.main.bundleIdentifier ?? "")
        //
        // if let dynamicLinksDomain = configurationManager.getAppConfiguration()?.firebase?.dynamicLinksDomain {
        //     actionCodeSettings.dynamicLinkDomain = dynamicLinksDomain
        // }
        //
        // try await auth.sendSignInLink(toEmail: email, actionCodeSettings: actionCodeSettings)
        
        print("📧 Sign-in link would be sent to: \(email)")
    }
    
    public func isSignInWithEmailLink(_ url: URL) -> Bool {
        // TODO: Implement when Firebase is added
        // return auth.isSignIn(withEmailLink: url.absoluteString)
        return url.absoluteString.contains("finishSignUp")
    }
    
    public func signIn(withEmail email: String, linkURL: URL) async throws {
        guard isValidEmail(email) else {
            throw AccountServiceError.invalidEmail
        }
        
        // TODO: Implement when Firebase is added
        // let result = try await auth.signIn(withEmail: email, link: linkURL.absoluteString)
        // await handleSuccessfulSignIn(result.user)
        
        // Temporary stub user for testing
        currentUser = AccountUser(uid: UUID().uuidString, email: email)
        
        // Clear pending email
        userDefaults.removeObject(forKey: CacheKeys.pendingEmail)
        
        print("✅ Signed in with email link: \(email)")
    }
    
    public func createUser(email: String, password: String) async throws {
        guard isValidEmail(email) else {
            throw AccountServiceError.invalidEmail
        }
        
        guard password.count >= 6 else {
            throw AccountServiceError.weakPassword
        }
        
        // TODO: Implement when Firebase is added
        // do {
        //     let result = try await auth.createUser(withEmail: email, password: password)
        //     await handleSuccessfulSignIn(result.user)
        // } catch let error as NSError {
        //     throw mapFirebaseError(error)
        // }
        
        // Temporary stub user for testing
        currentUser = AccountUser(uid: UUID().uuidString, email: email)
        
        print("✅ Created user account: \(email)")
    }
    
    public func signIn(email: String, password: String) async throws {
        guard isValidEmail(email) else {
            throw AccountServiceError.invalidEmail
        }
        
        // TODO: Implement when Firebase is added
        // do {
        //     let result = try await auth.signIn(withEmail: email, password: password)
        //     await handleSuccessfulSignIn(result.user)
        // } catch let error as NSError {
        //     throw mapFirebaseError(error)
        // }
        
        // Temporary stub user for testing
        currentUser = AccountUser(uid: UUID().uuidString, email: email)
        
        print("✅ Signed in with password: \(email)")
    }

    public func sendPasswordResetEmail(to email: String) async throws {
        guard isValidEmail(email) else {
            throw AccountServiceError.invalidEmail
        }

        // TODO: Implement when Firebase is added
        // try await auth.sendPasswordReset(withEmail: email)

        print("📧 Password reset email would be sent to: \(email)")
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

        // TODO: Implement when Firebase is added
        // try await auth.confirmPasswordReset(withCode: trimmedCode, newPassword: newPassword)
        // await handleSuccessfulSignIn(auth.currentUser)

        print("🔐 Password reset confirmed for code: \(trimmedCode.prefix(4))***")
    }
    
    public func signOut() async throws {
        // TODO: Implement when Firebase is added
        // try auth.signOut()
        
        currentUser = nil
        print("👋 Signed out")
    }
    
    public func deleteAccount() async throws {
        guard currentUser != nil else {
            throw AccountServiceError.notAuthenticated
        }
        
        // TODO: Implement when Firebase is added
        // guard let user = auth.currentUser else {
        //     throw AccountServiceError.notAuthenticated
        // }
        //
        // // Delete Firestore data
        // let uid = user.uid
        // try await firestore.collection("users").document(uid).delete()
        //
        // // Delete auth account
        // try await user.delete()
        
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
        
        // TODO: Implement when Firebase is added
        // try await firestore.collection("users").document(user.uid).collection("profile").document("info").setData([
        //     "marketingOptIn": enabled,
        //     "updatedAt": FieldValue.serverTimestamp()
        // ], merge: true)
        
        print("📧 Marketing opt-in updated: \(enabled)")
    }
    
    // MARK: - Settings Sync Methods
    
    public func syncSettingsSnapshot(_ snapshot: SettingsSnapshot) async throws {
        guard let user = currentUser else {
            throw AccountServiceError.notAuthenticated
        }
        
        // TODO: Implement when Firebase is added
        // let data: [String: Any] = [
        //     "calculationMethod": snapshot.calculationMethod,
        //     "madhab": snapshot.madhab,
        //     "timeFormat": snapshot.timeFormat,
        //     "notificationsEnabled": snapshot.notificationsEnabled,
        //     "notificationOffset": snapshot.notificationOffset,
        //     "liveActivitiesEnabled": snapshot.liveActivitiesEnabled,
        //     "showArabicSymbolInWidget": snapshot.showArabicSymbolInWidget,
        //     "userName": snapshot.userName,
        //     "hasCompletedOnboarding": snapshot.hasCompletedOnboarding,
        //     "settingsVersion": snapshot.settingsVersion,
        //     "lastSyncDate": Timestamp(date: snapshot.lastSyncDate)
        // ]
        //
        // try await firestore.collection("users").document(user.uid).collection("settings").document("current").setData(data)
        
        print("☁️ Settings synced to cloud for user: \(user.uid)")
    }
    
    public func fetchSettingsSnapshot() async throws -> SettingsSnapshot? {
        guard let user = currentUser else {
            throw AccountServiceError.notAuthenticated
        }
        
        // TODO: Implement when Firebase is added
        // let doc = try await firestore.collection("users").document(user.uid).collection("settings").document("current").getDocument()
        //
        // guard doc.exists, let data = doc.data() else {
        //     return nil
        // }
        //
        // return SettingsSnapshot(
        //     calculationMethod: data["calculationMethod"] as? String ?? "muslimWorldLeague",
        //     madhab: data["madhab"] as? String ?? "shafi",
        //     timeFormat: data["timeFormat"] as? String ?? "12",
        //     notificationsEnabled: data["notificationsEnabled"] as? Bool ?? true,
        //     notificationOffset: data["notificationOffset"] as? Double ?? 300,
        //     liveActivitiesEnabled: data["liveActivitiesEnabled"] as? Bool ?? true,
        //     showArabicSymbolInWidget: data["showArabicSymbolInWidget"] as? Bool ?? true,
        //     userName: data["userName"] as? String ?? "",
        //     hasCompletedOnboarding: data["hasCompletedOnboarding"] as? Bool ?? false,
        //     settingsVersion: data["settingsVersion"] as? Int ?? 1,
        //     lastSyncDate: (data["lastSyncDate"] as? Timestamp)?.dateValue() ?? Date()
        // )
        
        print("☁️ Settings fetched from cloud for user: \(user.uid)")
        return nil
    }
    
    // MARK: - Private Helpers
    
    private func loadCurrentUser() {
        // TODO: Implement when Firebase is added
        // if let firebaseUser = auth.currentUser {
        //     currentUser = AccountUser(
        //         uid: firebaseUser.uid,
        //         email: firebaseUser.email
        //     )
        //     print("👤 Loaded current user: \(firebaseUser.email ?? "unknown")")
        // }
    }
    
    private func handleSuccessfulSignIn(_ firebaseUser: Any) async {
        // TODO: Implement when Firebase is added
        // currentUser = AccountUser(
        //     uid: firebaseUser.uid,
        //     email: firebaseUser.email
        // )
        //
        // // Create or update profile document
        // let profileData: [String: Any] = [
        //     "email": firebaseUser.email ?? "",
        //     "createdAt": FieldValue.serverTimestamp(),
        //     "lastLoginAt": FieldValue.serverTimestamp(),
        //     "marketingOptIn": userDefaults.bool(forKey: CacheKeys.marketingOptIn)
        // ]
        //
        // try? await firestore.collection("users").document(firebaseUser.uid).collection("profile").document("info").setData(profileData, merge: true)
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private func mapFirebaseError(_ error: NSError) -> AccountServiceError {
        // TODO: Map Firebase error codes when available
        // switch error.code {
        // case AuthErrorCode.emailAlreadyInUse.rawValue:
        //     return .emailAlreadyInUse
        // case AuthErrorCode.userNotFound.rawValue:
        //     return .userNotFound
        // case AuthErrorCode.wrongPassword.rawValue:
        //     return .wrongPassword
        // case AuthErrorCode.networkError.rawValue:
        //     return .networkError
        // default:
        //     return .unknown(error)
        // }
        return .unknown(error)
    }
}
