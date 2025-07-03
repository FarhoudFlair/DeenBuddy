# 4-Engineer Parallel Task Breakdown - Deen Assist iOS App

## Engineer 1: Core Data & Prayer Engine
**Domain:** Data persistence, prayer calculations, local storage

### Setup & Foundation
- [ ] Create Xcode project with SwiftUI template
- [ ] Add Swift Package Manager dependencies (AdhanSwift, CoreData)
- [ ] Configure SwiftLint rules and project structure
- [ ] Set up Info.plist with required permissions

### CoreData Implementation
- [ ] Design CoreData model (.xcdatamodeld):
  - UserSettings entity (calculationMethod, madhab, notificationsEnabled, theme)
  - PrayerCache entity (date, fajr, dhuhr, asr, maghrib, isha, sourceMethod)
  - GuideContent entity (contentId, title, rakahCount, localData, videoURL, lastUpdatedAt)
- [ ] Generate NSManagedObject subclasses
- [ ] Create CoreDataManager with full CRUD operations
- [ ] Implement data migration handling

### Prayer Calculation Engine
- [ ] Create PrayerTimeCalculator wrapper around AdhanSwift
- [ ] Implement calculation method mapping (MuslimWorldLeague, MoonsightingCommittee, etc.)
- [ ] Add location-based calculation with lat/lon inputs
- [ ] Create 24-hour prayer time caching mechanism
- [ ] Handle timezone conversion and daylight saving transitions
- [ ] Create prayer time comparison and validation logic

### Testing & Validation
- [ ] Unit tests for PrayerTimeCalculator (15+ global cities)
- [ ] CoreData persistence tests with edge cases
- [ ] Prayer time accuracy tests against known values
- [ ] Data migration tests
- [ ] Performance tests for large datasets

---

## Engineer 2: Location & Network Services
**Domain:** Location services, API integration, system permissions

### Location Services
- [ ] Build LocationService with CoreLocation framework
- [ ] Implement automatic location detection with accuracy validation
- [ ] Add manual city search with geocoding
- [ ] Create location permission request flow with proper messaging
- [ ] Handle location errors and edge cases (denied, restricted, etc.)
- [ ] Add location caching and background updates

### AlAdhan API Integration
- [ ] Create APIClient with URLSession and proper error handling
- [ ] Implement prayer times endpoint (`/timings`) with parameter validation
- [ ] Implement qibla direction endpoint (`/qibla/{lat}/{lon}`)
- [ ] Add network reachability monitoring
- [ ] Create request throttling (90 req/min limit)
- [ ] Implement offline fallback mechanisms

### System Integration
- [ ] Create NotificationService for UNUserNotificationCenter
- [ ] Schedule prayer notifications 10 minutes before each prayer
- [ ] Handle notification permissions and user preferences
- [ ] Create notification content with prayer names and times
- [ ] Add notification action handling and user interaction
- [ ] Test notification scheduling across different time zones

### Service Protocols & Mocks
- [ ] Define LocationServiceProtocol, APIClientProtocol, NotificationServiceProtocol
- [ ] Create mock implementations for other engineers to use
- [ ] Add dependency injection container
- [ ] Create service registration and resolution system

---

## Engineer 3: UI/UX & User Experience
**Domain:** SwiftUI screens, navigation, user interactions

### Design System & Foundation
- [ ] Create comprehensive color palette and typography system
- [ ] Build reusable SwiftUI components (buttons, cards, inputs, loaders)
- [ ] Set up navigation structure with NavigationStack
- [ ] Create theme manager supporting Light/Dark/System modes
- [ ] Design app icon and launch screen assets

### Onboarding Flow
- [ ] Welcome screen with app introduction and value proposition
- [ ] Location permission request screen with clear explanation
- [ ] Calculation method selection screen with descriptions
- [ ] Madhab selection for Asr calculation (Shafi/Hanafi)
- [ ] Notification permission request with benefits explanation
- [ ] Onboarding completion with smooth transition to home

### Core Application Screens
- [ ] Home screen with next prayer countdown (live updates)
- [ ] Horizontal scrollable prayer times for current day
- [ ] Prayer status indicators (completed/upcoming/current)
- [ ] Quick access buttons to Compass and Prayer Guides
- [ ] Pull-to-refresh functionality for prayer times
- [ ] Handle prayer time transitions and state updates

### Settings & Configuration
- [ ] Settings screen with organized sections
- [ ] Calculation method picker with detailed descriptions
- [ ] Madhab selection toggle with explanations
- [ ] Theme selection with live preview
- [ ] Notification preferences with granular controls
- [ ] About section with app info, version, and licenses
- [ ] Data management options (clear cache, reset settings)

### Advanced UI Features
- [ ] Proper navigation flow between all screens
- [ ] State management with @StateObject and @ObservedObject
- [ ] Loading states and error handling UI
- [ ] Accessibility labels and VoiceOver support
- [ ] Dynamic type support for text scaling
- [ ] Haptic feedback for key interactions
- [ ] Smooth animations and transitions

### Testing & Polish
- [ ] XCUITest framework implementation
- [ ] UI automation tests for critical user flows
- [ ] Snapshot testing for visual regression
- [ ] Accessibility testing with VoiceOver
- [ ] Performance testing for smooth scrolling and animations

---

## Engineer 4: Specialized Features & DevOps
**Domain:** Qibla compass, prayer guides, content management, CI/CD

### Qibla Compass Implementation
- [ ] Implement CoreMotion for device orientation and magnetometer
- [ ] Calculate qibla direction using great circle formula
- [ ] Create compass UI with smooth needle pointing to Kaaba
- [ ] Add magnetic declination correction for accuracy
- [ ] Implement tilt compensation using accelerometer data
- [ ] Create sensor fusion for smooth, stable rotation
- [ ] Add calibration detection and user guidance prompts
- [ ] Calculate and display distance to Kaaba
- [ ] Handle edge cases (near poles, magnetic interference)

### Prayer Guides System
- [ ] Set up Supabase project with storage buckets and authentication
- [ ] Create content ingestion pipeline (Markdown + MP4 → JSON)
- [ ] Design native guide format (structured text, images, rakah count)
- [ ] Implement guide content parser and validator
- [ ] Create "Make Available Offline" toggle with download progress
- [ ] Add content versioning and update detection
- [ ] Implement HLS video player with custom controls
- [ ] Create video caching for offline playback

### Prayer Guide UI Components
- [ ] Guide selection screen with Sunni/Shia classification
- [ ] Individual guide detail view with rich content display
- [ ] Interactive rakah counter (full-screen overlay)
  - Single tap to advance count
  - Current rakah display (e.g., "2 / 4")
  - Long-press or swipe to exit
  - Subtle haptic feedback
- [ ] Video player integration with playback controls
- [ ] Offline content management and storage optimization

### Content Management & Updates
- [ ] Automated content update checking (weekly cron)
- [ ] Content download queue and progress tracking
- [ ] Storage optimization and cleanup routines
- [ ] Content integrity validation
- [ ] Backup and restore functionality for user content

### CI/CD & DevOps Pipeline
- [ ] GitHub Actions workflow configuration
- [ ] Fastlane setup for automated builds and testing
- [ ] TestFlight distribution automation
- [ ] Code signing with certificates and provisioning profiles
- [ ] Automated testing pipeline (unit + UI tests)
- [ ] Build artifact management and versioning
- [ ] Crash reporting integration (Firebase Crashlytics)
- [ ] App Store Connect API integration for metadata updates

### Release Management
- [ ] Version tagging and release notes automation
- [ ] Beta testing distribution and feedback collection
- [ ] App Store submission automation
- [ ] Post-release monitoring and analytics setup

## Integration Protocol

### Phase 1: Independent Development
- All engineers work against protocol mocks
- Daily integration builds to catch breaking changes
- Shared constants file for prayer names, calculation methods, etc.

### Phase 2: Service Integration
- Replace protocol mocks with concrete implementations
- Integration testing between all components
- Performance optimization and memory leak detection

### Phase 3: End-to-End Testing
- Complete user flow testing
- Beta build distribution and feedback incorporation
- Final polish and App Store submission

## Critical Dependencies to Monitor
- **CoreData schema changes** (Engineer 1) → UI updates (Engineer 3)
- **Location permissions** (Engineer 2) → Compass functionality (Engineer 4)
- **Prayer time calculations** (Engineer 1) → Notification scheduling (Engineer 2)
- **Content format** (Engineer 4) → Guide display (Engineer 3)

## Success Criteria
- All engineers can work independently without blocking others
- Clean integration with minimal conflicts
- Feature-complete app ready for beta testing
- Robust error handling and offline capabilities
- Smooth user experience across all flows