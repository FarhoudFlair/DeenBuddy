# Quick Start Guide for Engineers 2, 3, and 4

## Getting Started

The foundation (Engineer 1) is complete! Here's how to quickly get started with your part of the project.

## Project Structure Overview

```
DeenAssist/
├── Sources/DeenAssist/
│   ├── App/                          # Main app entry point
│   └── Core/
│       ├── Data/                     # CoreData implementation
│       ├── Prayer/                   # Prayer calculation engine
│       └── Protocols/                # Interfaces + Mocks
├── Tests/                            # Comprehensive test suite
├── Package.swift                     # Dependencies
└── README.md                         # Full documentation
```

## For Engineer 2 (Location & Network Services)

### Your Dependencies
```swift
import DeenAssist

// Use these protocols in your implementations
let prayerCalculator: PrayerCalculatorProtocol = MockPrayerCalculator()
let dataManager: DataManagerProtocol = MockDataManager()
```

### Key Integration Points
1. **Location Services**: Provide coordinates to `PrayerCalculationConfig`
2. **Network Layer**: Use for AlAdhan API integration
3. **Notifications**: Schedule using calculated prayer times

### Example Usage
```swift
// Get prayer times for user's location
let config = PrayerCalculationConfig(
    calculationMethod: .muslimWorldLeague,
    madhab: .shafi,
    location: userLocation, // Your location service provides this
    timeZone: TimeZone.current
)

let prayerTimes = try prayerCalculator.calculatePrayerTimes(for: Date(), config: config)
```

## For Engineer 3 (UI/UX)

### Your Dependencies
```swift
import DeenAssist
import SwiftUI

// Use these in your ViewModels
@EnvironmentObject var dependencies: AppDependencies
// dependencies.dataManager: DataManagerProtocol
// dependencies.prayerCalculator: PrayerCalculatorProtocol
```

### Key Integration Points
1. **User Settings**: Use `DataManagerProtocol` for settings management
2. **Prayer Times**: Display times from `PrayerCalculatorProtocol`
3. **Navigation**: Build on top of existing `ContentView`

### Example Usage
```swift
struct PrayerTimesView: View {
    @EnvironmentObject var dependencies: AppDependencies
    @State private var prayerTimes: PrayerTimes?
    
    var body: some View {
        VStack {
            if let times = prayerTimes {
                Text("Fajr: \(formatTime(times.fajr))")
                Text("Dhuhr: \(formatTime(times.dhuhr))")
                // ... other prayer times
            }
        }
        .onAppear {
            loadPrayerTimes()
        }
    }
    
    private func loadPrayerTimes() {
        // Use dependencies.prayerCalculator to get prayer times
    }
}
```

## For Engineer 4 (Specialized Features & DevOps)

### Your Dependencies
```swift
import DeenAssist
import CoreLocation
import CoreMotion

// Use these for content management
let dataManager: DataManagerProtocol = MockDataManager()
```

### Key Integration Points
1. **Qibla Compass**: Use prayer calculation for location context
2. **Prayer Guides**: Use `GuideContent` model and `DataManagerProtocol`
3. **Content Management**: Leverage existing offline storage system

### Example Usage
```swift
// Manage prayer guide content
let guides = dataManager.getAllGuideContent()
let offlineGuides = dataManager.getOfflineGuideContent()

// Save new guide content
let newGuide = GuideContent(
    contentId: "fajr_sunni_guide",
    title: "Fajr Prayer (Sunni)",
    rakahCount: 2,
    isAvailableOffline: true,
    localData: guideData,
    videoURL: "https://example.com/video.m3u8",
    lastUpdatedAt: Date()
)
try dataManager.saveGuideContent(newGuide)
```

## Running Tests

```bash
# In the DeenAssist directory
swift test

# Run specific test file
swift test --filter PrayerTimeCalculatorTests
swift test --filter CoreDataManagerTests
```

## Using Mock Implementations

During development, use the provided mocks:

```swift
// Instead of real implementations
let mockCalculator = MockPrayerCalculator()
let mockDataManager = MockDataManager()

// Use the same interfaces
let prayerTimes = try mockCalculator.calculatePrayerTimes(for: Date(), config: config)
let settings = mockDataManager.getUserSettings()
```

## Key Models to Know

### PrayerTimes
```swift
struct PrayerTimes {
    let date: Date
    let fajr: Date
    let dhuhr: Date
    let asr: Date
    let maghrib: Date
    let isha: Date
    let calculationMethod: String
}
```

### UserSettings
```swift
struct UserSettings {
    let id: UUID
    let calculationMethod: String  // CalculationMethod.rawValue
    let madhab: String            // Madhab.rawValue
    let notificationsEnabled: Bool
    let theme: String            // "light", "dark", "system"
}
```

### GuideContent
```swift
struct GuideContent {
    let contentId: String
    let title: String
    let rakahCount: Int16
    let isAvailableOffline: Bool
    let localData: Data?
    let videoURL: String?
    let lastUpdatedAt: Date
}
```

## Common Patterns

### Error Handling
```swift
do {
    let prayerTimes = try calculator.calculatePrayerTimes(for: date, config: config)
    // Handle success
} catch PrayerCalculationError.invalidLocation {
    // Handle invalid location
} catch PrayerCalculationError.calculationFailed(let message) {
    // Handle calculation failure
} catch {
    // Handle other errors
}
```

### Async Operations
```swift
Task {
    do {
        let prayerTimes = try calculator.calculatePrayerTimes(for: date, config: config)
        await MainActor.run {
            // Update UI
        }
    } catch {
        // Handle error
    }
}
```

## Integration Checklist

### Before You Start
- [ ] Read the main README.md
- [ ] Review the protocol definitions
- [ ] Run the existing tests to understand the foundation
- [ ] Look at mock implementations for examples

### During Development
- [ ] Use the provided protocols (don't create your own interfaces)
- [ ] Write tests for your components
- [ ] Use mock implementations for dependencies
- [ ] Follow the existing code style (SwiftLint configured)

### Before Integration
- [ ] Ensure your code works with mock implementations
- [ ] Write integration tests
- [ ] Update documentation for your components
- [ ] Verify performance requirements are met

## Getting Help

1. **Check the README.md** for comprehensive documentation
2. **Look at test files** for usage examples
3. **Review mock implementations** for interface contracts
4. **Check protocol documentation** for method signatures

## Performance Guidelines

- **Prayer Calculations**: Should complete in < 10ms
- **UI Updates**: Should be smooth (60fps)
- **Data Operations**: Should complete in < 50ms
- **Memory Usage**: Keep under 50MB for normal usage

## Code Style

The project uses SwiftLint with a comprehensive configuration. Key points:
- Line length: 120 characters (warning), 150 (error)
- Use MARK comments for organization
- Avoid force unwrapping in production code
- Document public APIs

## Ready to Build!

The foundation is solid and ready for you to build amazing features on top of it. The protocols are well-defined, thoroughly tested, and designed for easy integration.

Happy coding! 🚀
