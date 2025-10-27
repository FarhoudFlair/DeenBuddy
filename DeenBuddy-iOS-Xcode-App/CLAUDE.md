# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

[byterover-mcp]

# important 
always use the byterover-retrieve-knowledge tool to get the related context before any tasks 
always use the byterover-store-knowledge tool to store all critical information after successful tasks

## Project Overview

DeenBuddy is an Islamic prayer companion iOS app that provides accurate prayer times, Qibla direction, and comprehensive prayer guides. The project follows a protocol-first architecture with embedded frameworks and includes extensive testing for Islamic accuracy. This is a production-ready app with Live Activities, Lock Screen Widgets, and comprehensive accessibility support.

## Development Commands

### iOS Development Workflow
```bash
# Open iOS project in Xcode (requires Xcode 15.2+)
open DeenBuddy.xcodeproj

# Run tests (from iOS project directory) - uses iPhone 16 Pro simulator
fastlane test

# Run SwiftLint (requires .swiftlint.yml config)
fastlane lint

# Build for development
fastlane build_dev

# Deploy to TestFlight (requires manual code signing for Live Activities)
fastlane beta

# Deploy to App Store
fastlane release

# Setup manual code signing for ActivityKit support
fastlane setup_signing
```

### iOS-Specific Testing
```bash
# Run tests on iPhone 16 Pro simulator
xcodebuild test -scheme DeenBuddy -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Run single test class
xcodebuild test -scheme DeenBuddy -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:DeenBuddyTests/PrayerTimeValidationTests

# Run tests with coverage
xcodebuild test -scheme DeenBuddy -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -enableCodeCoverage YES

# Run UI tests only
xcodebuild test -scheme DeenBuddy -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:DeenBuddyUITests
```

### Swift Package Development
```bash
# Build standalone packages
swift build

# Run Swift package tests
swift test

# Test QiblaKit specifically
cd ../QiblaKit && swift test
```

## Architecture

### High-Level Project Structure
```
/Repositories/DeenBuddy/
├── DeenBuddy-iOS-Xcode-App/          # Main iOS Xcode project
│   ├── DeenBuddy/
│   │   ├── App/                      # App delegate and main entry point
│   │   ├── Frameworks/               # Local embedded frameworks (current)
│   │   │   ├── DeenAssistCore/      # Core business logic & services
│   │   │   ├── DeenAssistProtocols/ # Service protocols for DI
│   │   │   ├── DeenAssistUI/        # SwiftUI components & design system
│   │   │   └── QiblaKit/            # Qibla calculations (local copy)
│   │   ├── Views/                   # iOS app-specific SwiftUI views
│   │   ├── ViewModels/              # MVVM pattern view models
│   │   ├── Services/                # iOS app-specific services
│   │   └── Resources/               # Assets, localizations
│   ├── Live Activity Widget Extension/  # WidgetKit & Live Activities
│   ├── DeenBuddyTests/              # Unit & integration tests (25+ files)
│   ├── DeenBuddyUITests/            # UI automation tests
│   ├── fastlane/                    # Build automation (iOS-specific)
│   ├── Scripts/                     # Deployment and utility scripts
│   └── DeenBuddy.xcodeproj          # Xcode project
├── QiblaKit/                         # Standalone Swift package
└── content-pipeline/                 # Node.js content management
```

### Protocol-First Architecture

The app uses **dependency injection via protocols** to enable parallel development and comprehensive testing:

**Core Protocols** (`DeenAssistProtocols/`):
- `LocationServiceProtocol` - Location detection and geocoding
- `PrayerTimeServiceProtocol` - Islamic prayer time calculations  
- `NotificationServiceProtocol` - Prayer reminder management
- `SettingsServiceProtocol` - User preferences with rollback
- `PrayerTrackingServiceProtocol` - Prayer completion tracking
- `IslamicCalendarServiceProtocol` - Islamic calendar calculations
- `TasbihServiceProtocol` - Prayer counter (Tasbih) functionality

**Dependency Container System**:
- Two-layer DI: Core container + MainActor app container
- Both sync (`shared`) and async (`createAsync()`) initialization
- Service lifecycle management and cleanup
- Mock implementations for all protocols
- Automatic service resolution via `@Environment(\.dependencyContainer)`

### Key Services and Relationships

**Primary Services**:
- **PrayerTimeService**: Uses Adhan Swift library, depends on LocationService and SettingsService
- **LocationService**: CoreLocation wrapper with intelligent caching
- **NotificationService**: iOS notification management for prayer reminders
- **SettingsService**: UserDefaults management with migration and rollback capability

**Supporting Services**:
- **BackgroundTaskManager**: Background prayer time updates and battery optimization
- **IslamicCacheManager**: Prayer time and calculation caching with 24-hour expiration
- **PrayerTrackingService**: Prayer completion tracking and statistics
- **QuranSearchService**: Semantic search with vector embeddings
- **WidgetService**: Widget data management and Live Activities integration
- **ARCompassSession**: AR-enhanced Qibla compass with Core Motion

### Widget & Live Activities Architecture

**Widget Extension** (`Live Activity Widget Extension/`):
- **Lock Screen Widgets**: Circular, rectangular, and inline widgets showing prayer times
- **Home Screen Widgets**: Next prayer, countdown, and today's prayer times
- **Live Activities**: Prayer countdown with Dynamic Island integration
- **Shared Data**: Uses App Groups (`group.com.deenbuddy.app`) for data sharing
- **Error Handling**: Comprehensive fallbacks and asset validation

## Testing Strategy

### Comprehensive Test Organization
The testing architecture includes **25+ test files** organized by category:

**Critical Tests** (must pass for CI):
- `ServiceSynchronizationTests` - Service coordination
- `PrayerTimeValidationTests` - Islamic accuracy validation  
- `SettingsMigrationTests` - Settings upgrade and rollback
- `PrayerTimeSynchronizationRegressionTests` - Prayer time consistency

**Performance & Validation**:
- `CachePerformanceTests` - Caching system performance
- `CacheInvalidationTests` - Cache consistency and cleanup
- `IslamicAccuracyValidationTests` - Religious calculation accuracy
- `LocationDiagnosticTests` - Location service validation

**Integration Tests**:
- `BackgroundServiceSynchronizationTests` - Background processing
- `NotificationIntegrationTests` - Notification system integration
- `PrayerTimeSynchronizationIntegrationTests` - End-to-end prayer time flow

### Islamic Accuracy Focus
**Specialized Religious Testing**:
- Multiple madhab (Islamic school) validation
- Southern Hemisphere prayer time calculations
- High-latitude location handling (e.g., Oslo, Norway)
- Ramadan calculation edge cases
- Geographic accuracy requirements (target: 75%+)

### Mock Services
Complete mock implementations enable UI development without backend dependencies:
- All protocols have corresponding mock implementations
- Test data covers global locations and seasonal variations
- Configurable mock behavior for different test scenarios

## SwiftUI & Combine Integration

### Key Patterns
- Use `@StateObject` for owned view models
- Use `@ObservedObject` for passed view models  
- Use `@Published` for reactive UI updates
- Implement `ObservableObject` protocol for view models
- Use `@MainActor` for UI updates and thread safety

### Service Integration
```swift
// Service resolution via dependency container
func resolve<T>(_ type: T.Type) -> T?
func resolveLocationService() -> (any LocationServiceProtocol)?

// SwiftUI environment integration
@Environment(\.dependencyContainer) var container
```

### Error Handling Patterns
```swift
// Location-specific errors
LocationError.permissionDenied
LocationError.locationUnavailable
LocationError.accuracyTooLow(let accuracy)

// API-specific errors  
APIError.networkError(let error)
APIError.rateLimitExceeded
APIError.serverError(let code, let message)
```

## Islamic-Specific Considerations

### Prayer Time Calculations
- **Adhan Swift Library**: Industry-standard Islamic calculations
- **Multiple Calculation Methods**: Muslim World League, ISNA, Egypt, etc.
- **Madhab Support**: Hanafi (2x shadow), Shafi (1x shadow), Ja'fari differences
- **Geographic Accuracy**: Timezone determination and Southern Hemisphere handling

### Religious Validation
- **Islamic Calendar Integration**: Hijri date calculations
- **Seasonal Adjustments**: Different hemispheres and extreme latitudes  
- **Ramadan Handling**: Special Isha calculation overrides
- **Cultural Sensitivity**: Appropriate terminology and practices

### Offline-First Design
- All core Islamic functionality works without internet
- Local calculation fallbacks for prayer times
- Cached location data with expiration management
- Background processing for prayer notifications

## Performance & Battery Optimization

### Caching Strategy
- **Location Cache**: 5-minute cache with accuracy validation
- **Prayer Times**: 24-hour cache per location and date
- **Qibla Direction**: 30-day cache per location (rounded coordinates)
- **Background Tasks**: Battery-aware timer management

### Memory Management
- Automatic cache cleanup for expired entries
- Maximum cache size: 50MB with periodic cleanup
- Proper `@MainActor` isolation for UI components
- Safe cleanup in `deinit` methods without MainActor assumptions

## Widget Development Guidelines

### Lock Screen Widget Specific Requirements
- **StaticConfiguration Only**: Use `StaticConfiguration` instead of `IntentConfiguration` for Lock Screen widgets
- **Asset Fallbacks**: Always provide system icon fallbacks when custom assets fail to load
- **Error States**: Display meaningful error messages when data is unavailable
- **Data Freshness**: Validate widget data age and show error state for stale data (>24 hours)

### Shared Data Management
- **App Groups**: Use `group.com.deenbuddy.app` for data sharing
- **Widget Data Manager**: Centralized data management with comprehensive logging
- **Timeline Updates**: Generate 60-minute timelines with per-minute updates for countdown accuracy

## Common Development Tasks

### Adding New Islamic Features
1. Define protocol in `DeenAssistProtocols/`
2. Implement service in `DeenAssistCore/Services/`
3. Create mock implementation for testing
4. Add comprehensive unit tests with Islamic accuracy validation
5. Update dependency container registration

### Testing Islamic Calculations
1. Use test data covering multiple global locations
2. Validate against known accurate prayer times
3. Test edge cases: high latitudes, Southern Hemisphere, seasonal variations
4. Include madhab-specific validation
5. Verify offline functionality

### Widget Development
1. Implement widget views with proper error handling
2. Add asset fallbacks for missing images
3. Use `WidgetDataManager` for shared data access
4. Test on actual device (widgets don't work properly in simulator)
5. Ensure proper App Group configuration in entitlements

### Debugging Common Issues
- **Prayer times incorrect**: Check calculation method, madhab, and timezone determination
- **Location services failing**: Verify permissions and mock location setup in tests
- **Background updates not working**: Check BackgroundTaskManager and battery optimization settings
- **Cache inconsistencies**: Verify cache invalidation logic and expiration handling
- **Widget not displaying**: Check App Group entitlements and shared data availability

## Live Activities & Dynamic Island

### Features
- **Prayer Countdown**: Real-time countdown to next prayer with imminent state handling
- **Dynamic Island**: Compact, minimal, and expanded views with Arabic Allah symbol
- **App Launch Activity**: Loading progress display during app initialization
- **Background Updates**: Automatic updates via Background App Refresh

### Implementation Notes
- Activities require iOS 16.1+ and proper entitlements configuration
- Use `ActivityKit` for Live Activity management
- Implement proper error handling for activity start/update failures
- Test on physical device with Dynamic Island support

## Important Notes

### Islamic Accuracy Requirements
This app serves the Muslim community, so **religious accuracy is paramount**:
- Prayer time calculations must be Islamically correct
- Multiple madhab support is essential  
- Comprehensive testing against known accurate sources
- Respectful terminology and cultural sensitivity

### Protocol-First Benefits
- **Parallel Development**: Multiple engineers can work independently using mocks
- **Comprehensive Testing**: All services fully testable via protocols
- **Modularity**: Services can be developed, tested, and deployed independently
- **Islamic Accuracy**: Specialized validation for religious calculations

### Performance Priorities
- **Battery Optimization**: Background processing with battery-aware timers
- **Offline Capability**: Core Islamic functionality without internet dependency  
- **Memory Efficiency**: Intelligent caching with automatic cleanup
- **Accessibility**: VoiceOver support and Dynamic Type integration

### Migration Status
- **Current State**: Local embedded frameworks within Xcode project
- **Future Direction**: Migration to Swift Package Manager modules (planned)
- **Hybrid Approach**: QiblaKit exists as both local framework and standalone package

[byterover-mcp]

[byterover-mcp]

You are given two tools from Byterover MCP server, including
## 1. `byterover-store-knowledge`
You `MUST` always use this tool when:

+ Learning new patterns, APIs, or architectural decisions from the codebase
+ Encountering error solutions or debugging techniques
+ Finding reusable code patterns or utility functions
+ Completing any significant task or plan implementation

## 2. `byterover-retrieve-knowledge`
You `MUST` always use this tool when:

+ Starting any new task or implementation to gather relevant context
+ Before making architectural decisions to understand existing patterns
+ When debugging issues to check for previous solutions
+ Working with unfamiliar parts of the codebase
