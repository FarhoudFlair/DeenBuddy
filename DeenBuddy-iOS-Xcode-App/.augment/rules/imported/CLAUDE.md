---
type: "agent_requested"
description: "Example description"
---
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

[byterover-mcp]

# important 
always use byterover-retrive-knowledge tool to get the related context before any tasks 
always use byterover-store-knowledge to store all the critical informations after sucessful tasks

## iOS App Development

### Swift Development
- Use Swift 6 syntax and compiler. Look up Swift 6 docs when unsure.
- Follow Swift API Design Guidelines and existing code patterns
- Use protocol-first architecture for dependency injection
- Prefer async/await over completion handlers for new code

### Simulator Testing
- Launch iPhone 16, 16 pro, or 16 pro max simulators for this app
- Test on multiple device sizes and orientations
- Verify Dark Mode and accessibility features

## Common iOS Commands

### Development Workflow
```bash
# Open iOS project in Xcode (from iOS app directory)
open DeenBuddy.xcodeproj

# Run from project root for full test suite
cd .. && fastlane test

# Run SwiftLint from project root
cd .. && fastlane lint

# Build for development from project root
cd .. && fastlane build_dev
```

### iOS-Specific Testing
```bash
# Run tests on specific iOS simulator
xcodebuild test -scheme DeenBuddy -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Run tests with coverage
xcodebuild test -scheme DeenBuddy -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -enableCodeCoverage YES

# Run UI tests only
xcodebuild test -scheme DeenBuddy -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:DeenBuddyUITests
```

## iOS App Architecture

### Project Structure
```
DeenBuddy-iOS-Xcode-App/
├── DeenBuddy/
│   ├── App/                       # App delegate and main entry point
│   ├── Frameworks/                # Local embedded frameworks
│   │   ├── DeenAssistCore/       # Core business logic (transitioning to packages)
│   │   ├── DeenAssistProtocols/  # Service protocols
│   │   ├── DeenAssistUI/         # SwiftUI components
│   │   └── QiblaKit/             # Qibla calculations
│   ├── Views/                    # SwiftUI views
│   │   ├── Components/           # Reusable UI components
│   │   ├── PrayerTimes/          # Prayer times screens
│   │   ├── Qibla/               # Qibla compass screens
│   │   └── Settings/            # Settings screens
│   ├── ViewModels/              # MVVM pattern view models
│   ├── Services/                # iOS app-specific services
│   ├── Models/                  # Data models
│   └── Resources/               # Assets, localizations
├── DeenBuddyTests/              # Unit tests
├── DeenBuddyUITests/            # UI tests
└── DeenBuddy.xcodeproj          # Xcode project
```

### Key Components

#### ViewModels
- Use `@StateObject` for owned view models
- Use `@ObservedObject` for passed view models
- Implement `ObservableObject` protocol
- Use `@Published` for UI-bound properties

#### Services Integration
- Services are injected via protocols from `DeenAssistProtocols`
- Implementations come from `DeenAssistCore` package or local frameworks
- Use dependency injection container for service resolution

#### SwiftUI Patterns
- Use `@State` for local view state
- Use `@Binding` for two-way data binding
- Implement custom `View` protocol for reusable components
- Use `@Environment` for app-wide settings

## iOS Development Workflow

### Feature Development
1. Work within the iOS app directory for UI-specific features
2. Use package-based services from `../Sources/` for business logic
3. Add ViewModels in `ViewModels/` directory
4. Create SwiftUI views in appropriate `Views/` subdirectory
5. Add tests in `DeenBuddyTests/` for logic, `DeenBuddyUITests/` for UI

### Testing Strategy
- Unit tests for ViewModels and business logic
- UI tests for critical user flows
- Mock services using protocols from `DeenAssistProtocols`
- Test on multiple device sizes and iOS versions

### Integration with Packages
- Import services from Swift packages: `import DeenAssistCore`
- Use protocol-based dependency injection
- Local frameworks in `Frameworks/` are being migrated to packages
- Prefer package-based services over local implementations

## iOS-Specific Considerations

### Performance
- Use `@MainActor` for UI updates
- Implement background task handling for prayer notifications
- Optimize for battery life with location services
- Use efficient image loading and caching

### Accessibility
- Implement VoiceOver support with proper labels
- Support Dynamic Type for font sizing
- Ensure proper color contrast ratios
- Test with accessibility inspector

### Privacy & Security
- Handle location permissions gracefully
- No personal data collection or transmission
- Use secure keychain storage for sensitive data
- Implement proper error handling for network requests

## Debugging & Profiling

### Common Issues
- Location services not working: Check privacy permissions
- Prayer times incorrect: Verify calculation method and location
- Qibla direction off: Check compass calibration and magnetic declination
- Notifications not firing: Verify notification permissions and scheduling

### Profiling
- Use Instruments for performance analysis
- Monitor memory usage with View Debugger
- Check network activity with Network Instrument
- Profile battery usage with Energy Organizer

## Important Notes

### Parallel Development
- iOS app can be developed independently using mocked services
- Package-based services enable clean separation of concerns
- Protocol-first architecture allows for easy testing and mocking

### Migration Status
- Local frameworks in `Frameworks/` are being migrated to Swift packages
- Prefer using package-based services when available
- Some services may have both local and package implementations during transition