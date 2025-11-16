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

## Step 8: Configure Custom Domain for Magic Links (Optional)

**Note**: Firebase Dynamic Links is deprecated. For magic links, you can use:

1. **Firebase Hosting** (recommended): Host a simple HTML page that redirects to your app
2. **Custom domain**: Configure your own domain for email action links
3. **Universal Links**: Use Apple's Universal Links for seamless deep linking

For Firebase Hosting approach:
1. In Firebase Console, go to **"Hosting"** → **"Get started"**
2. Follow setup instructions to connect a custom domain
3. Create the following files in your hosting directory:

**`index.html`** (main page):
```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>DeenBuddy - Sign In</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            text-align: center;
            padding: 50px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            min-height: 100vh;
            margin: 0;
        }
        .container {
            max-width: 400px;
            margin: 0 auto;
            background: rgba(255, 255, 255, 0.1);
            padding: 40px;
            border-radius: 10px;
            backdrop-filter: blur(10px);
        }
        h1 { margin-bottom: 20px; }
        p { margin-bottom: 30px; opacity: 0.9; }
        .btn {
            display: inline-block;
            padding: 12px 24px;
            background: white;
            color: #667eea;
            text-decoration: none;
            border-radius: 25px;
            font-weight: 600;
            transition: transform 0.2s;
        }
        .btn:hover { transform: translateY(-2px); }
    </style>
</head>
<body>
    <div class="container">
        <h1>🕌 DeenBuddy</h1>
        <p>Welcome! Click below to open the app and complete your sign-in.</p>
        <a href="#" onclick="openApp()" class="btn">Open DeenBuddy</a>
    </div>

    <script>
        function openApp() {
            // Try to open the app with the current URL
            const currentUrl = window.location.href;
            const appScheme = 'deenbuddy://';

            // Try app scheme first
            window.location.href = appScheme + currentUrl.split('://')[1];

            // Fallback: redirect to app store or show message
            setTimeout(() => {
                document.querySelector('.container').innerHTML = `
                    <h1>🕌 DeenBuddy</h1>
                    <p>If the app didn't open automatically, please open DeenBuddy manually to complete your sign-in.</p>
                    <p style="font-size: 14px; opacity: 0.8;">You can close this browser tab now.</p>
                `;
            }, 2000);
        }

        // Auto-attempt to open app when page loads
        window.onload = openApp;
    </script>
</body>
</html>
```

**`firebase.json`** (hosting configuration):
```json
{
  "hosting": {
    "public": "public",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ]
  }
}
```

4. Deploy: `firebase deploy --only hosting`

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
### 9.3: Wire Password Reset UI

`AccountSettingsScreen` now exposes a **“Send Password Reset Email”** button that calls `userAccountService.sendPasswordResetEmail(to:)` for the currently signed-in user. Success and error states are shown inline via the screen’s existing messaging banner.


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

#### Password reset helpers

`FirebaseUserAccountService` now implements both password reset entry points:

```swift
try await auth.sendPasswordReset(withEmail: email)
try await auth.confirmPasswordReset(withCode: trimmedCode, newPassword: newPassword)
```

Any `NSError` coming back from Firebase is mapped through `mapFirebaseError(_:)`, so UI layers can surface friendly `AccountServiceError` values (invalid email, weak password, etc.).

#### Cloud settings sync

- `syncSettingsSnapshot(_:)` writes to `users/{uid}/settings/current`.
- `fetchSettingsSnapshot()` reads the same document and rebuilds a `SettingsSnapshot`.
- `AppCoordinator` calls `applyCloudSettingsIfAvailable()` after each successful sign-in. If a snapshot exists, it is loaded and applied via the new `SettingsService.applySnapshot(_:)` helper (which temporarily toggles `isRestoring` so individual property observers don’t fire).
- The Firestore document mirrors `SettingsSnapshot`:

| Field                       | Type      |
|-----------------------------|-----------|
| `calculationMethod`         | String    |
| `madhab`                    | String    |
| `timeFormat`                | String    |
| `notificationsEnabled`      | Bool      |
| `notificationOffset`        | Double    |
| `liveActivitiesEnabled`     | Bool      |
| `showArabicSymbolInWidget`  | Bool      |
| `userName`                  | String    |
| `hasCompletedOnboarding`    | Bool      |
| `settingsVersion`           | Int       |
| `lastSyncDate`              | Timestamp |

This keeps cloud and local settings in sync across devices.

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

## Step 11: Firebase Initialization & URL Handling

**Firebase initialization is already configured** in the app via `AppCoordinator.start()`. The app calls `FirebaseInitializer.configureIfNeeded()` early in the startup process.

**✅ URL handling for magic links is already configured** in `DeenBuddyApp.swift` with the `onOpenURL` modifier that calls `appCoordinator.handleMagicLink(url)`.

**Note**: Do NOT add `UIApplicationDelegateAdaptor` or Firebase initialization code to `DeenBuddyApp.swift` - it's already handled by `FirebaseInitializer` in the AppCoordinator.

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
   - Trigger a password reset email from `AccountSettingsScreen`

## Step 13: Security Checklist

- [ ] `GoogleService-Info.plist` is **NOT** committed to git (add to `.gitignore`)
- [ ] Firestore security rules are configured for production
- [ ] Authentication methods are properly enabled in Firebase Console
- [ ] Magic links configured (Firebase Hosting or custom domain)
- [ ] Test authentication flows work correctly

## Troubleshooting

### Error: "FirebaseApp.configure() can only be called once"
- ✅ Already handled by `FirebaseInitializer` with `isConfigured` flag
- If you see this error, check that you're not calling `FirebaseApp.configure()` manually anywhere else in your code

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
- Check that Firebase Hosting or custom domain is properly configured
- Ensure `onOpenURL` handler is in app entry point
- Verify the email action URL matches your configured domain

### Authentication Errors
- Check Firebase Console → Authentication → Sign-in methods are enabled
- Verify email/password and email link are both enabled
- Check Firestore rules allow authenticated users

## Next Steps

1. **Set up Firestore Security Rules** for production (include `users/{uid}/settings/current`)
2. **Configure Firebase Analytics** (if desired)
3. **Set up Firebase Crashlytics** for error reporting
4. **Test all authentication flows** thoroughly (email/password, magic link, password reset)
5. **Configure Firebase Hosting** or custom domain for magic links (if using)

## Additional Resources

- [Firebase iOS Documentation](https://firebase.google.com/docs/ios/setup)
- [Firebase Auth Documentation](https://firebase.google.com/docs/auth/ios/start)
- [Firestore Documentation](https://firebase.google.com/docs/firestore/ios/start)
- [Firebase Hosting](https://firebase.google.com/docs/hosting) (for custom domains)
- [Universal Links Setup](https://developer.apple.com/documentation/xcode/supporting-universal-links-in-your-app)

## Important Notes

- **Firebase Dynamic Links is deprecated** and will be shut down. Use Firebase Hosting or Universal Links instead.
- **Magic links work without custom domains** but provide a better user experience with them.
- **Test thoroughly** before deploying to production, especially authentication flows.

---

**Note**: Remember to add `GoogleService-Info.plist` to `.gitignore` to prevent committing sensitive keys to version control!

