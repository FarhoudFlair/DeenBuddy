# Firebase Quick Start Checklist

## ✅ Setup Checklist

### 1. Firebase Console Setup
- [ ] Create Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
- [ ] Add iOS app with your bundle ID
- [ ] Download `GoogleService-Info.plist`
- [ ] Enable **Email/Password** authentication
- [ ] Enable **Email link** authentication
- [ ] Create Firestore database (test mode for dev)
- [ ] (Optional) Configure Firebase Hosting or a custom domain for magic links

### 2. Xcode Setup
- [ ] Add `GoogleService-Info.plist` to `DeenBuddy/App/` folder
- [ ] Add Firebase SDK via Swift Package Manager:
  - URL: `https://github.com/firebase/firebase-ios-sdk`
  - Products: `FirebaseAuth`, `FirebaseFirestore`, `FirebaseCore`
- [ ] Configure URL Scheme in Info.plist for magic links

### 3. Code Updates
- [ ] Uncomment Firebase imports in `FirebaseInitializer.swift`
- [ ] Uncomment `FirebaseApp.configure()` in `FirebaseInitializer.swift`
- [ ] Uncomment Firebase code in `FirebaseUserAccountService.swift`
- [ ] Remove stub user assignments (lines 80, 106, 125)
- [ ] Add `onOpenURL` handler in `DeenBuddyApp.swift`

### 4. Testing
- [ ] Build project (⌘B) - should compile without errors
- [ ] Run app and check console for "🔥 Firebase configured successfully"
- [ ] Test account creation
- [ ] Test email/password sign-in
- [ ] Test magic link sign-in

## 🔧 Key Files to Update

1. **`DeenBuddy/App/FirebaseInitializer.swift`**
   - Uncomment `import FirebaseCore`
   - Uncomment `FirebaseApp.configure()`

2. **`DeenBuddy/Frameworks/DeenAssistCore/Services/FirebaseUserAccountService.swift`**
   - Uncomment all Firebase imports and code
   - Remove stub user assignments

3. **`DeenBuddy/App/DeenBuddyApp.swift`**
   - Add `.onOpenURL { url in appCoordinator.handleMagicLink(url) }`

## 🚨 Important Notes

- ✅ `GoogleService-Info.plist` is already in `.gitignore` (won't be committed)
- ✅ Firebase initialization is thread-safe (handled by `FirebaseInitializer`)
- ✅ Test environment detection prevents Firebase init during tests
- ✅ All authentication methods update `currentUser` properly

## 📚 Full Documentation

See `FIREBASE_SETUP_GUIDE.md` for detailed step-by-step instructions.

