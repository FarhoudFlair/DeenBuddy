# Engineer 1: iOS Project Configuration

## 🚨 **Critical Context: What Went Wrong**
We accidentally built a **macOS Swift Package** instead of an **iOS App** for DeenBuddy. The good news: our Supabase backend is perfect with all 10 prayer guides (5 Sunni + 5 Shia) successfully uploaded and working. We need to convert this to a proper iOS app.

## ✅ **What's Already Working**
- **Supabase Database**: 10 prayer guides uploaded and accessible
- **Content Pipeline**: All Islamic prayer content created and validated
- **API Integration**: Supabase connection logic exists (needs iOS adaptation)
- **Core Logic**: Prayer guide models and business logic are sound

## 🎯 **Your Role: iOS Project Configuration**
You're responsible for configuring the iOS Xcode project settings, Info.plist, build configurations, and ensuring the project is properly set up for iOS development. You'll create the foundation that all other engineers will build upon.

## 📁 **Current Codebase Structure**
```
DeenBuddy/
├── Package.swift                    ← Engineer 5 will modify
├── Sources/
│   └── DeenAssistCore/
│       ├── Models/                  ← Engineer 2 will modify
│       │   ├── PrayerGuide.swift
│       │   ├── Prayer.swift
│       │   └── Madhab.swift
│       └── Services/                ← Engineer 3 will modify
│           └── SupabaseService.swift
├── content-pipeline/                ← Keep as-is (working)
└── DeenBuddyApp/                   ← Your files to configure
    ├── DeenBuddyApp.swift
    ├── ContentView.swift
    └── Info.plist
```

## 📋 **Your Specific Files to Work On**
**Primary Files:**
- `DeenBuddyApp/Info.plist` - Configure iOS permissions and settings
- Xcode Project Settings - Build configurations, signing, capabilities
- Project Navigator Organization - Set up proper folder structure

**Secondary Files:**
- `.gitignore` updates for iOS-specific files
- Build scheme configurations
- Asset catalog setup

## 🎯 **Deliverables & Acceptance Criteria**

### **1. Info.plist Configuration**
Configure iOS-specific permissions and settings:

```xml
<!-- Add these to Info.plist -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>DeenBuddy needs location access to calculate accurate prayer times for your area.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>DeenBuddy needs location access to provide prayer time notifications.</string>

<key>UIBackgroundModes</key>
<array>
    <string>background-fetch</string>
    <string>background-processing</string>
</array>

<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>supabase.co</key>
        <dict>
            <key>NSIncludesSubdomains</key>
            <true/>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <false/>
            <key>NSExceptionMinimumTLSVersion</key>
            <string>TLSv1.2</string>
        </dict>
    </dict>
</dict>

<key>UISupportedInterfaceOrientations</key>
<array>
    <string>UIInterfaceOrientationPortrait</string>
    <string>UIInterfaceOrientationLandscapeLeft</string>
    <string>UIInterfaceOrientationLandscapeRight</string>
</array>
```

### **2. Xcode Project Settings**
- **Deployment Target**: iOS 16.0 minimum
- **Bundle Identifier**: `com.deenbuddy.app`
- **Display Name**: "DeenBuddy"
- **Version**: 1.0
- **Build Number**: 1

### **3. Capabilities Configuration**
Enable these capabilities in Xcode:
- **Background Modes**: Background fetch, Background processing
- **Push Notifications**: For prayer time reminders
- **Location Services**: For prayer time calculations

### **4. Build Configurations**
Set up proper Debug/Release configurations:
- **Debug**: Enable debugging, disable optimizations
- **Release**: Enable optimizations, disable debugging symbols

### **5. Project Organization**
Create proper folder structure in Xcode Navigator:
```
DeenBuddy/
├── App/
│   ├── DeenBuddyApp.swift
│   └── Info.plist
├── Views/                    ← For Engineer 4
├── Models/                   ← For Engineer 2
├── Services/                 ← For Engineer 3
├── iOS Features/             ← For Engineer 6
└── Resources/
    └── Assets.xcassets
```

## 🔗 **Dependencies & Coordination**

### **You Enable:**
- **Engineer 2**: Needs proper iOS project to test model integration
- **Engineer 3**: Needs iOS build target for Supabase service testing
- **Engineer 4**: Needs project structure to add SwiftUI views
- **Engineer 5**: Needs iOS project to integrate Swift packages
- **Engineer 6**: Needs capabilities configured for iOS features

### **You Depend On:**
- **None** - You're the foundation that enables everyone else

### **Coordination Points:**
- **With Engineer 5**: Coordinate on Swift Package integration
- **With Engineer 6**: Ensure capabilities are properly configured

## ⚠️ **Critical Requirements**

### **iOS-Specific Settings:**
1. **Remove any macOS references** from project settings
2. **Set iOS 16.0+ deployment target** (not macOS)
3. **Configure proper iOS signing** and provisioning
4. **Enable iOS-specific capabilities** (Location, Notifications)

### **Supabase Integration Prep:**
1. **App Transport Security** must allow Supabase domains
2. **Network permissions** for API calls
3. **Background modes** for data sync

### **Testing Setup:**
1. **iOS Simulator** configuration
2. **Unit test target** setup
3. **UI test target** setup

## ✅ **Acceptance Criteria**

### **Must Have:**
- [ ] iOS project builds without errors in Xcode
- [ ] Deployment target set to iOS 16.0+
- [ ] Info.plist contains all required iOS permissions
- [ ] App Transport Security configured for Supabase
- [ ] Project folder structure organized for team development
- [ ] Build configurations properly set for Debug/Release

### **Should Have:**
- [ ] Capabilities enabled for Location and Notifications
- [ ] Background modes configured
- [ ] Proper bundle identifier and app metadata
- [ ] Asset catalog set up for app icons

### **Nice to Have:**
- [ ] Launch screen configured
- [ ] App icon placeholders added
- [ ] Accessibility settings configured

## 🚀 **Success Validation**
1. **Build Test**: Project builds successfully for iOS Simulator
2. **Settings Verification**: All iOS-specific settings are configured
3. **Team Readiness**: Other engineers can start their work immediately
4. **No Blockers**: No configuration issues preventing development

## 📞 **Support & Escalation**
- **Blocked by project settings?** You're the expert - document solutions
- **Need Swift Package integration help?** Coordinate with Engineer 5
- **Capability configuration issues?** Work with Engineer 6

**Estimated Time**: 2-4 hours
**Priority**: HIGHEST - Everyone depends on your work
