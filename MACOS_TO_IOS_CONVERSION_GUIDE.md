# DeenBuddy: macOS to iOS Conversion Guide

## 🚨 Current Situation
We accidentally built a **macOS Swift Package** instead of an **iOS App**. This guide provides step-by-step instructions for multiple engineers to work in parallel converting it to a proper iOS app.

## 📋 Team Assignment & Parallel Tasks

### 👨‍💻 **Engineer 1: iOS Project Configuration**
**Files to work on:** Xcode project settings, configuration files
**No conflicts with:** Any other engineer

#### Tasks:
1. **Configure iOS project settings** (Xcode project already created)
   ```
   - Verify Bundle Identifier: com.deenbuddy.app
   - Set Deployment Target: iOS 16.0+
   - Configure signing & capabilities
   - Set up proper build configurations
   ```

2. **Set up proper iOS project structure**
   ```
   DeenBuddy.xcodeproj/
   DeenBuddy/
   ├── App/
   │   ├── DeenBuddyApp.swift
   │   └── Info.plist
   ├── Views/
   │   ├── ContentView.swift
   │   ├── PrayerGuideListView.swift
   │   └── PrayerGuideDetailView.swift
   ├── Models/
   │   ├── PrayerGuide.swift
   │   └── Prayer.swift
   ├── Services/
   │   ├── SupabaseService.swift
   │   └── PrayerTimeService.swift
   ├── Resources/
   │   ├── Assets.xcassets
   │   └── Localizable.strings
   └── Supporting Files/
   ```

3. **Configure iOS-specific settings**
   - Verify deployment target is iOS 16.0
   - Configure supported orientations (Portrait, Landscape)
   - Set up App Transport Security for Supabase
   - Add required device capabilities
   - Configure Info.plist for location services and notifications

### 👩‍💻 **Engineer 2: Core Models Migration**
**Files to work on:** `Sources/DeenAssistCore/Models/`
**No conflicts with:** Engineer 1, 3, 4

#### Tasks:
1. **Convert PrayerGuide model for iOS**
   ```swift
   // Remove macOS-specific imports
   // Add iOS-specific features
   // Ensure Codable compliance for Supabase
   ```

2. **Update Prayer enum**
   ```swift
   enum Prayer: String, CaseIterable, Codable {
       case fajr = "fajr"
       case dhuhr = "dhuhr" 
       case asr = "asr"
       case maghrib = "maghrib"
       case isha = "isha"
   }
   ```

3. **Create Madhab enum for iOS**
   ```swift
   enum Madhab: String, CaseIterable, Codable {
       case sunni = "sunni"
       case shia = "shia"
   }
   ```

4. **Add iOS-specific model properties**
   - Location-based features
   - Notification preferences
   - Offline storage capabilities

### 👨‍💻 **Engineer 3: Supabase Service iOS Adaptation**
**Files to work on:** `Sources/DeenAssistCore/Services/SupabaseService.swift`
**No conflicts with:** Engineer 1, 2, 4

#### Tasks:
1. **Remove macOS-specific code**
   ```swift
   // Remove: import AppKit
   // Remove: macOS-specific networking
   // Remove: macOS platform checks
   ```

2. **Add iOS-specific imports**
   ```swift
   import Foundation
   import UIKit
   import Combine
   import Network
   ```

3. **Update SupabaseService for iOS**
   ```swift
   @MainActor
   class SupabaseService: ObservableObject {
       @Published var prayerGuides: [PrayerGuide] = []
       @Published var isLoading = false
       @Published var errorMessage: String?
       
       // iOS-specific networking
       // Background task handling
       // Offline caching
   }
   ```

4. **Implement iOS networking patterns**
   - URLSession with proper iOS lifecycle
   - Background app refresh support
   - Network reachability monitoring
   - Proper error handling for mobile

5. **Add offline support**
   - Core Data integration
   - Local caching strategy
   - Sync mechanism

### 👩‍💻 **Engineer 4: SwiftUI Views for iOS**
**Files to work on:** New iOS Views directory
**No conflicts with:** Engineer 1, 2, 3

#### Tasks:
1. **Create main ContentView for iOS**
   ```swift
   struct ContentView: View {
       @StateObject private var supabaseService = SupabaseService()
       @State private var selectedMadhab: Madhab = .sunni
       
       var body: some View {
           NavigationStack {
               // iOS-specific navigation
               // Tab view for different sections
               // Prayer time display
           }
       }
   }
   ```

2. **Create PrayerGuideListView**
   ```swift
   struct PrayerGuideListView: View {
       let guides: [PrayerGuide]
       let madhab: Madhab
       
       var body: some View {
           List {
               // iOS-optimized list
               // Pull-to-refresh
               // Search functionality
           }
       }
   }
   ```

3. **Create PrayerGuideDetailView**
   ```swift
   struct PrayerGuideDetailView: View {
       let guide: PrayerGuide
       
       var body: some View {
           ScrollView {
               // Full prayer instructions
               // Arabic text with proper fonts
               // Audio playback controls
               // Bookmark functionality
           }
       }
   }
   ```

4. **Add iOS-specific UI components**
   - Tab bar navigation
   - Pull-to-refresh
   - Search bar
   - Settings view
   - Prayer time widgets

### 👨‍💻 **Engineer 5: Dependencies & Package Management**
**Files to work on:** Package dependencies, SPM integration
**No conflicts with:** Any other engineer

#### Tasks:
1. **Convert Package.swift for iOS**
   ```swift
   // swift-tools-version: 5.9
   import PackageDescription
   
   let package = Package(
       name: "DeenBuddyCore",
       platforms: [
           .iOS(.v16)  // Remove macOS platform
       ],
       products: [
           .library(name: "DeenBuddyCore", targets: ["DeenBuddyCore"])
       ],
       dependencies: [
           .package(url: "https://github.com/supabase/supabase-swift", from: "2.0.0"),
           .package(url: "https://github.com/batoulapps/adhan-swift", from: "1.0.0")
       ],
       targets: [
           .target(
               name: "DeenBuddyCore",
               dependencies: [
                   .product(name: "Supabase", package: "supabase-swift"),
                   .product(name: "Adhan", package: "adhan-swift")
               ]
           )
       ]
   )
   ```

2. **Add iOS-specific dependencies**
   - Core Location for prayer times
   - UserNotifications for prayer reminders
   - Core Data for offline storage
   - AVFoundation for audio playback

3. **Set up Swift Package Manager integration with Xcode**
   - Add package dependencies to iOS project
   - Configure proper linking
   - Set up module imports

### 👩‍💻 **Engineer 6: iOS-Specific Features**
**Files to work on:** New iOS feature implementations
**No conflicts with:** Any other engineer

#### Tasks:
1. **Implement Location Services**
   ```swift
   import CoreLocation
   
   class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
       @Published var location: CLLocation?
       @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
       
       private let locationManager = CLLocationManager()
       
       // iOS location handling
       // Prayer time calculations based on location
   }
   ```

2. **Add Prayer Time Calculations**
   ```swift
   import Adhan
   
   class PrayerTimeService: ObservableObject {
       @Published var prayerTimes: PrayerTimes?
       @Published var nextPrayer: Prayer?
       
       // Calculate prayer times for current location
       // Handle timezone changes
       // Provide countdown to next prayer
   }
   ```

3. **Implement Push Notifications**
   ```swift
   import UserNotifications
   
   class NotificationService: ObservableObject {
       // Schedule prayer time notifications
       // Handle notification permissions
       // Customize notification content
   }
   ```

4. **Add iOS App Lifecycle handling**
   ```swift
   // Background app refresh
   // Scene lifecycle management
   // State restoration
   ```

## 🔧 **Critical Fixes Required**

### **Remove macOS-specific code:**
```swift
// REMOVE these imports:
import AppKit
import Cocoa

// REMOVE these platform checks:
#if os(macOS)

// REMOVE macOS-specific UI code:
NSView, NSViewController, etc.
```

### **Add iOS-specific code:**
```swift
// ADD these imports:
import UIKit
import SwiftUI
import CoreLocation
import UserNotifications

// ADD iOS platform checks:
#if os(iOS)

// ADD iOS-specific UI code:
UIView, UIViewController, etc.
```

## 📱 **iOS App Configuration**

### **Info.plist additions:**
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>DeenBuddy needs location access to calculate accurate prayer times for your area.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>DeenBuddy needs location access to provide prayer time notifications.</string>

<key>UIBackgroundModes</key>
<array>
    <string>background-fetch</string>
    <string>background-processing</string>
</array>
```

### **App Transport Security:**
```xml
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
        </dict>
    </dict>
</dict>
```

## 🧪 **Testing Strategy**

### **Engineer 1 & 2:** Unit Tests
- Model serialization/deserialization
- Prayer time calculations
- Supabase integration

### **Engineer 3 & 4:** UI Tests
- Navigation flows
- Data loading states
- Error handling

### **Engineer 5 & 6:** Integration Tests
- End-to-end prayer guide loading
- Location services
- Notification scheduling

## 📦 **Deliverables Checklist**

- [ ] **Engineer 1:** iOS Xcode project created and configured
- [ ] **Engineer 2:** Core models converted and iOS-ready
- [ ] **Engineer 3:** Supabase service working on iOS
- [ ] **Engineer 4:** SwiftUI views implemented for iOS
- [ ] **Engineer 5:** Dependencies properly configured for iOS
- [ ] **Engineer 6:** iOS-specific features implemented

## 🚀 **Final Integration**

Once all engineers complete their tasks:

1. **Merge all changes** into the new iOS project
2. **Test on iOS Simulator** and physical devices
3. **Verify Supabase integration** works on iOS
4. **Test all 10 prayer guides** load correctly
5. **Validate location services** and prayer times
6. **Prepare for TestFlight** distribution

## ⚠️ **Critical Notes**

- **No merge conflicts** if engineers stick to their assigned files
- **Test frequently** on iOS Simulator during development
- **Coordinate** any shared model changes through Engineer 2
- **iOS 16.0+** minimum deployment target for modern SwiftUI features
- **Supabase credentials** remain the same across platforms

This conversion should take **2-3 days** with the team working in parallel.

## 📋 **Detailed Technical Specifications**

### **Current macOS Issues to Fix:**

1. **Platform Target**: Currently building for macOS 10.15+, needs iOS 16.0+
2. **UIKit Dependencies**: Code imports UIKit but builds for macOS
3. **Swift Package Structure**: Designed as library, needs iOS app target
4. **Navigation**: Uses macOS navigation patterns, needs iOS NavigationStack
5. **Networking**: Uses macOS URLSession patterns, needs iOS-optimized networking

### **iOS-Specific Requirements:**

#### **App Architecture:**
```
iOS App (Main Target)
├── DeenBuddyCore (Swift Package)
│   ├── Models (Shared)
│   ├── Services (iOS-adapted)
│   └── Utilities (iOS-adapted)
└── iOS-Specific Features
    ├── Location Services
    ├── Push Notifications
    ├── Background Tasks
    └── Core Data Stack
```

#### **Key iOS Adaptations Needed:**

1. **SupabaseService.swift** - Remove macOS networking, add iOS patterns
2. **Models/** - Ensure all models work with iOS Core Data
3. **Package.swift** - Change platform from macOS to iOS
4. **Navigation** - Convert to iOS NavigationStack/TabView
5. **Lifecycle** - Add iOS app lifecycle management

### **Priority Order:**
1. **Engineer 1** (Project Setup) - Start immediately
2. **Engineer 5** (Dependencies) - Start after Engineer 1 creates project
3. **Engineers 2,3,4,6** - Start in parallel after project exists

### **Success Criteria:**
- [ ] App builds and runs on iOS Simulator
- [ ] Connects to Supabase and loads all 10 prayer guides
- [ ] Displays proper iOS navigation and UI
- [ ] Location services work for prayer times
- [ ] No macOS dependencies remain
