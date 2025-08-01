# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

[byterover-mcp]

# important 
always use byterover-retrive-knowledge tool to get the related context before any tasks 
always use byterover-store-knowledge to store all the critical informations after sucessful tasks

## Project Overview

DeenBuddy is an Islamic prayer companion iOS app that provides accurate prayer times, Qibla direction, and comprehensive prayer guides. The project follows a protocol-first architecture with embedded frameworks and includes extensive testing for Islamic accuracy.

## Development Commands

### iOS Development Workflow
```bash
# Open iOS project in Xcode
open DeenBuddy.xcodeproj

# Run tests (from iOS project directory)
fastlane test

# Run SwiftLint  
fastlane lint

# Build for development
fastlane build_dev

# Deploy to TestFlight
fastlane beta

# Deploy to App Store
fastlane release
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

**Dependency Container System**:
- Two-layer DI: Core container + MainActor app container
- Both sync (`shared`) and async (`createAsync()`) initialization
- Service lifecycle management and cleanup
- Mock implementations for all protocols

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

## Swift Development Patterns

### SwiftUI & Combine Integration
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

### Debugging Common Issues
- **Prayer times incorrect**: Check calculation method, madhab, and timezone determination
- **Location services failing**: Verify permissions and mock location setup in tests
- **Background updates not working**: Check BackgroundTaskManager and battery optimization settings
- **Cache inconsistencies**: Verify cache invalidation logic and expiration handling

## Migration Status & Architecture Evolution

### Current State (Transitional)
- **Local Embedded Frameworks**: Current implementation uses frameworks within Xcode project
- **Planned Swift Packages**: Root `Package.swift` defines future SPM modules (not yet active)
- **Hybrid Approach**: Some components (QiblaKit) exist as both local frameworks and standalone packages

### Future Architecture
- Migration from local frameworks to Swift Package Manager modules
- Maintain protocol-first architecture during transition
- Preserve comprehensive testing and mock implementations
- Continue Islamic accuracy and offline-first principles

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