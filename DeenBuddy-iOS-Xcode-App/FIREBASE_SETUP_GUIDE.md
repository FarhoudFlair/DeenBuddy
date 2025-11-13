# Firebase Setup Guide for DeenBuddy iOS

This guide will walk you through setting up Firebase Authentication and Firestore for the DeenBuddy iOS app.

## Prerequisites

- Xcode 15.2 or later
- Apple Developer Account
- Firebase account (free tier is sufficient)
- DeenBuddy.xcodeproj project

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **"Add project"** or select an existing project
3. Enter project name: **"DeenBuddy"** (or your preferred name)
4. Enable/disable Google Analytics (optional, recommended: enabled)
5. Click **"Create project"**
6. Wait for project creation to complete

## Step 2: Add iOS App to Firebase

1. In Firebase Console, click **"Add app"** → Select **iOS** icon
2. Enter iOS bundle ID:
   - Find your bundle ID in Xcode: Select project → Target → General → Bundle Identifier
   - Example: `com.deenbuddy.app` or `com.yourcompany.deenbuddy`
3. Enter App nickname: **"DeenBuddy iOS"**
4. Enter App Store ID (optional, leave blank for now)
5. Click **"Register app"**

## Step 3: Download GoogleService-Info.plist

1. Click **"Download GoogleService-Info.plist"**
2. **IMPORTANT**: Do NOT add this file to git (it contains sensitive keys)
3. Open Finder and locate the downloaded file

## Step 4: Add GoogleService-Info.plist to Xcode

1. Open `DeenBuddy.xcodeproj` in Xcode
2. In Project Navigator, right-click on **`DeenBuddy/App/`** folder
3. Select **"Add Files to DeenBuddy..."**
4. Navigate to downloaded `GoogleService-Info.plist`
5. **IMPORTANT**: 
   - ✅ Check **"Copy items if needed"**
   - ✅ Select **"DeenBuddy"** target
   - ✅ Select **"DeenBuddy"** group (not "DeenBuddyTests")
6. Click **"Add"**
7. Verify the file appears in `DeenBuddy/App/GoogleService-Info.plist`

## Step 5: Add Firebase SDK via Swift Package Manager

1. In Xcode, select **Project** (top-level "DeenBuddy") in Navigator
2. Select **"DeenBuddy"** project (not target)
3. Click **"Package Dependencies"** tab
4. Click **"+"** button (bottom left)
5. Enter Firebase iOS SDK URL:
   ```
   https://github.com/firebase/firebase-ios-sdk
   ```
6. Click **"Add Package"**
7. Select version: **"Up to Next Major Version"** with **10.0.0** or latest
8. Click **"Add Package"**
9. Select these products (checkboxes):
   - ✅ **FirebaseAuth**
   - ✅ **FirebaseFirestore**
   - ✅ **FirebaseCore** (usually auto-selected)
10. Ensure **"DeenBuddy"** target is selected
11. Click **"Add Package"**
12. Wait for package resolution to complete

## Step 6: Enable Firebase Authentication

1. In Firebase Console, go to **"Authentication"** → **"Get started"**
2. Click **"Sign-in method"** tab
3. Enable **"Email/Password"**:
   - Click **"Email/Password"**
   - Toggle **"Enable"** to ON
   - Click **"Save"**
4. Enable **"Email link (passwordless sign-in)"**:
   - Click **"Email link (passwordless sign-in)"**
   - Toggle **"Enable"** to ON
   - Click **"Save"**

## Step 7: Enable Firestore Database

1. In Firebase Console, go to **"Firestore Database"** → **"Create database"**
2. Select **"Start in test mode"** (for development)
3. Choose location (closest to your users, e.g., `us-central1`)
4. Click **"Enable"**
5. **Security Rules** (update later for production):
   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /users/{userId} {
         allow read, write: if request.auth != null && request.auth.uid == userId;
       }
     }
   }
   ```

## Step 8: Configure Dynamic Links (Optional, for Magic Links)

1. In Firebase Console, go to **"Dynamic Links"** → **"Get started"**
2. Create a domain (e.g., `deenbuddy.page.link`)
3. Note the domain name for later configuration

## Step 9: Update Code to Use Firebase

### 9.1: Update FirebaseInitializer.swift

Open `DeenBuddy/App/FirebaseInitializer.swift` and uncomment Firebase code:

```swift
import Foundation
import FirebaseCore  // ✅ Uncomment this

/// Handles Firebase initialization with safety guards for testing
public class FirebaseInitializer {
    
    private static var isConfigured = false
    private static let lock = NSLock()
    
    /// Configure Firebase if not already configured
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
        
        FirebaseApp.configure()  // ✅ Uncomment this
        isConfigured = true      // ✅ Uncomment this
        print("🔥 Firebase configured successfully")  // ✅ Uncomment this
    }
    
    /// Reset configuration state (for testing purposes only)
    public static func resetForTesting() {
        lock.lock()
        defer { lock.unlock() }
        isConfigured = false
    }
}
```

### 9.2: Update FirebaseUserAccountService.swift

Open `DeenBuddy/Frameworks/DeenAssistCore/Services/FirebaseUserAccountService.swift`:

1. **Uncomment imports** (lines 2-4):
```swift
import Foundation
import FirebaseAuth      // ✅ Uncomment
import FirebaseFirestore // ✅ Uncomment
```

2. **Uncomment Firebase instances** (lines 17-19):
```swift
private let auth: Auth
private let firestore: Firestore
```

3. **Update init()** (lines 30-37):
```swift
public init() {
    self.auth = Auth.auth()                    // ✅ Uncomment
    self.firestore = Firestore.firestore()     // ✅ Uncomment
    
    // Load current user if authenticated
    loadCurrentUser()
}
```

4. **Update sendSignInLink()** (lines 41-62):
```swift
public func sendSignInLink(to email: String) async throws {
    guard isValidEmail(email) else {
        throw AccountServiceError.invalidEmail
    }
    
    // Store email for later verification
    userDefaults.set(email, forKey: CacheKeys.pendingEmail)
    
    let actionCodeSettings = ActionCodeSettings()  // ✅ Uncomment
    actionCodeSettings.url = URL(string: "https://deenbuddy.app/finishSignUp")
    actionCodeSettings.handleCodeInApp = true
    actionCodeSettings.setIOSBundleID(Bundle.main.bundleIdentifier ?? "")
    
    if let dynamicLinksDomain = configurationManager.getAppConfiguration()?.firebase?.dynamicLinksDomain {
        actionCodeSettings.dynamicLinkDomain = dynamicLinksDomain
    }
    
    try await auth.sendSignInLink(toEmail: email, actionCodeSettings: actionCodeSettings)  // ✅ Uncomment
    
    print("📧 Sign-in link sent to: \(email)")
}
```

5. **Update isSignInWithEmailLink()** (lines 64-68):
```swift
public func isSignInWithEmailLink(_ url: URL) -> Bool {
    return auth.isSignIn(withEmailLink: url.absoluteString)  // ✅ Uncomment
}
```

6. **Update signIn(withEmail:linkURL:)** (lines 70-86):
```swift
public func signIn(withEmail email: String, linkURL: URL) async throws {
    guard isValidEmail(email) else {
        throw AccountServiceError.invalidEmail
    }
    
    let result = try await auth.signIn(withEmail: email, link: linkURL.absoluteString)  // ✅ Uncomment
    await handleSuccessfulSignIn(result.user)  // ✅ Uncomment
    
    // Remove stub user assignment (line 80)
    // currentUser = AccountUser(uid: UUID().uuidString, email: email)  // ❌ Remove this
    
    // Clear pending email
    userDefaults.removeObject(forKey: CacheKeys.pendingEmail)
    
    print("✅ Signed in with email link: \(email)")
}
```

7. **Update createUser()** (lines 88-109):
```swift
public func createUser(email: String, password: String) async throws {
    guard isValidEmail(email) else {
        throw AccountServiceError.invalidEmail
    }
    
    guard password.count >= 6 else {
        throw AccountServiceError.weakPassword
    }
    
    do {
        let result = try await auth.createUser(withEmail: email, password: password)  // ✅ Uncomment
        await handleSuccessfulSignIn(result.user)  // ✅ Uncomment
    } catch let error as NSError {
        throw mapFirebaseError(error)  // ✅ Uncomment
    }
    
    // Remove stub user assignment (line 106)
    // currentUser = AccountUser(uid: UUID().uuidString, email: email)  // ❌ Remove this
    
    print("✅ Created user account: \(email)")
}
```

8. **Update signIn(email:password:)** (lines 111-128):
```swift
public func signIn(email: String, password: String) async throws {
    guard isValidEmail(email) else {
        throw AccountServiceError.invalidEmail
    }
    
    do {
        let result = try await auth.signIn(withEmail: email, password: password)  // ✅ Uncomment
        await handleSuccessfulSignIn(result.user)  // ✅ Uncomment
    } catch let error as NSError {
        throw mapFirebaseError(error)  // ✅ Uncomment
    }
    
    // Remove stub user assignment (line 125)
    // currentUser = AccountUser(uid: UUID().uuidString, email: email)  // ❌ Remove this
    
    print("✅ Signed in with password: \(email)")
}
```

9. **Update signOut()** (lines 130-137):
```swift
public func signOut() async throws {
    try auth.signOut()  // ✅ Uncomment
    
    currentUser = nil
    print("👋 Signed out")
}
```

10. **Update deleteAccount()** (lines 129-148):
```swift
public func deleteAccount() async throws {
    guard currentUser != nil else {
        throw AccountServiceError.notAuthenticated
    }
    
    guard let user = auth.currentUser else {  // ✅ Uncomment
        throw AccountServiceError.notAuthenticated
    }
    
    // Delete Firestore data
    let uid = user.uid
    try await firestore.collection("users").document(uid).delete()  // ✅ Uncomment
    
    // Delete auth account
    try await user.delete()  // ✅ Uncomment
    
    currentUser = nil
    print("🗑️ Account deleted")
}
```

11. **Update loadCurrentUser()** (lines 228-237):
```swift
private func loadCurrentUser() {
    if let firebaseUser = auth.currentUser {  // ✅ Uncomment
        currentUser = AccountUser(
            uid: firebaseUser.uid,
            email: firebaseUser.email
        )
        print("👤 Loaded current user: \(firebaseUser.email ?? "unknown")")
    }
}
```

12. **Update handleSuccessfulSignIn()** (lines 239-255):
```swift
private func handleSuccessfulSignIn(_ firebaseUser: User) async {  // ✅ Update type
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
    
    try? await firestore.collection("users").document(firebaseUser.uid).collection("profile").document("info").setData(profileData, merge: true)
}
```

13. **Update mapFirebaseError()** (lines 263-278):
```swift
private func mapFirebaseError(_ error: NSError) -> AccountServiceError {
    guard let authErrorCode = AuthErrorCode.Code(rawValue: error.code) else {  // ✅ Uncomment
        return .unknown(error)
    }
    
    switch authErrorCode {  // ✅ Uncomment
    case .emailAlreadyInUse:
        return .emailAlreadyInUse
    case .userNotFound:
        return .userNotFound
    case .wrongPassword:
        return .wrongPassword
    case .networkError:
        return .networkError
    case .invalidEmail:
        return .invalidEmail
    case .weakPassword:
        return .weakPassword
    default:
        return .unknown(error)
    }
}
```

## Step 10: Configure URL Scheme for Magic Links

1. In Xcode, select **"DeenBuddy"** target
2. Go to **"Info"** tab
3. Expand **"URL Types"**
4. Click **"+"** to add new URL Type
5. Enter:
   - **Identifier**: `com.deenbuddy.app` (or your bundle ID)
   - **URL Schemes**: `deenbuddy` (or your app name)
   - **Role**: `Editor`
6. Save

## Step 11: Update AppDelegate/SceneDelegate for URL Handling

The app already handles magic links via `AppCoordinator.handleMagicLink()`. Ensure your app delegate handles URLs:

In `DeenBuddyApp.swift`, add URL handling:

```swift
import SwiftUI

@main
struct DeenBuddyApp: App {
    private let appCoordinator = AppCoordinator.production()
    @StateObject private var userPreferencesService = UserPreferencesService()

    var body: some Scene {
        WindowGroup {
            EnhancedDeenAssistApp(coordinator: appCoordinator)
                .environmentObject(userPreferencesService)
                .onOpenURL { url in
                    // Handle magic link URLs
                    appCoordinator.handleMagicLink(url)
                }
        }
    }
}
```

## Step 12: Test Firebase Setup

1. **Build the project** (⌘B) - should compile without errors
2. **Run the app** (⌘R) on simulator or device
3. **Check console logs** for:
   - `🔥 Firebase configured successfully`
   - No Firebase-related errors

4. **Test Authentication**:
   - Try creating an account
   - Try signing in with email/password
   - Try magic link sign-in

## Step 13: Security Checklist

- [ ] `GoogleService-Info.plist` is **NOT** committed to git (add to `.gitignore`)
- [ ] Firestore security rules are configured for production
- [ ] Authentication methods are properly enabled in Firebase Console
- [ ] Dynamic Links domain is configured (if using magic links)
- [ ] Test authentication flows work correctly

## Troubleshooting

### Error: "FirebaseApp.configure() can only be called once"
- ✅ Already handled by `FirebaseInitializer` with `isConfigured` flag

### Error: "GoogleService-Info.plist not found"
- Check file is in `DeenBuddy/App/` folder
- Verify target membership includes "DeenBuddy" target
- Clean build folder (⌘⇧K) and rebuild

### Error: "No such module 'FirebaseAuth'"
- Verify Swift Package Manager resolved packages
- Clean build folder and rebuild
- Check Package Dependencies shows Firebase packages

### Magic Links Not Working
- Verify URL scheme is configured in Info.plist
- Check Dynamic Links domain is set in Firebase Console
- Ensure `onOpenURL` handler is in app entry point

### Authentication Errors
- Check Firebase Console → Authentication → Sign-in methods are enabled
- Verify email/password and email link are both enabled
- Check Firestore rules allow authenticated users

## Next Steps

1. **Set up Firestore Security Rules** for production
2. **Configure Firebase Analytics** (if desired)
3. **Set up Firebase Crashlytics** for error reporting
4. **Test all authentication flows** thoroughly
5. **Update ConfigurationManager** with Dynamic Links domain (if using)

## Additional Resources

- [Firebase iOS Documentation](https://firebase.google.com/docs/ios/setup)
- [Firebase Auth Documentation](https://firebase.google.com/docs/auth/ios/start)
- [Firestore Documentation](https://firebase.google.com/docs/firestore/ios/start)
- [Firebase Dynamic Links](https://firebase.google.com/docs/dynamic-links/ios/receive)

---

**Note**: Remember to add `GoogleService-Info.plist` to `.gitignore` to prevent committing sensitive keys to version control!

