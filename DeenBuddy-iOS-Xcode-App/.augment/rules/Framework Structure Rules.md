# DeenBuddy Framework Structure Rules

## Framework Organization

### 1. DeenAssistCore
- **Type**: Directory-based framework (NOT a Swift module)
- **Location**: `DeenBuddy/Frameworks/DeenAssistCore/`
- **Purpose**: Core business logic, services, and models
- **Import Pattern**: Access through main `@testable import DeenBuddy` in tests
- **Namespace**: Use `DeenAssistCore.ClassName` when needed for disambiguation

**Structure:**
```
DeenAssistCore/
├── Services/           # Core services (PrayerTimeService, LocationService, etc.)
├── Models/            # Data models (PrayerTracking, TasbihModels, etc.)
├── DependencyInjection/  # DI container and service registration
├── Mocks/             # Mock implementations for testing
├── Utilities/         # Helper classes and extensions
├── Configuration/     # App configuration and constants
├── ErrorHandling/     # Error handling and crash reporting
└── DeenAssistCore.swift  # Main module file
```

### 2. DeenAssistUI
- **Type**: Directory-based framework (NOT a Swift module)
- **Location**: `DeenBuddy/Frameworks/DeenAssistUI/`
- **Purpose**: SwiftUI components, screens, and navigation
- **Import Pattern**: Access through main `@testable import DeenBuddy` in tests
- **Namespace**: Use `DeenAssistUI.ClassName` when needed for disambiguation

**Structure:**
```
DeenAssistUI/
├── Components/        # Reusable UI components
├── Screens/          # Full screen views
├── Navigation/       # App coordinator and navigation logic
├── DesignSystem/     # Colors, typography, themes
├── Mocks/           # Mock UI services (MockSettingsService, etc.)
├── Localization/    # Localized strings
└── Resources/       # UI assets and resources
```

### 3. DeenAssistProtocols
- **Type**: Directory-based framework (NOT a Swift module)
- **Location**: `DeenBuddy/Frameworks/DeenAssistProtocols/`
- **Purpose**: Service protocols and interfaces
- **Import Pattern**: Access through main `@testable import DeenBuddy` in tests
- **Files**: Individual protocol files (SettingsServiceProtocol.swift, etc.)

## Import Rules for Test Files

### ✅ CORRECT Import Pattern
```swift
import XCTest
import Combine
import CoreLocation
@testable import DeenBuddy  // Main app module only

class MyTests: XCTestCase {
    // Access framework classes with namespace when needed
    private var settingsService: MockSettingsService!  // Local mock
    // OR
    private var settingsService: DeenAssistUI.MockSettingsService!  // Framework mock
}
```

### ❌ INCORRECT Import Pattern
```swift
@testable import DeenAssistUI      // ❌ Not a module - will fail
@testable import DeenAssistCore    // ❌ Not a module - will fail
@testable import DeenAssistProtocols // ❌ Not a module - will fail
```

## Mock Service Usage in Tests

### Option 1: Use Framework Mocks (Preferred)
```swift
// Access existing mocks from frameworks
private var settingsService: DeenAssistUI.MockSettingsService!
private var prayerTimeService: DeenAssistUI.MockPrayerTimeService!
private var locationService: DeenAssistUI.MockLocationService!

override func setUp() {
    settingsService = DeenAssistUI.MockSettingsService()
    // ...
}
```

### Option 2: Create Local Mocks (When framework mocks don't exist)
```swift
// Define local mock in test file
@MainActor
class MockSettingsService: SettingsServiceProtocol, ObservableObject {
    @Published var calculationMethod: CalculationMethod = .muslimWorldLeague
    @Published var madhab: Madhab = .shafi
    // ... implement required protocol methods
}

private var settingsService: MockSettingsService!
```

## Service Access Patterns

### In Production Code
```swift
// Access services through dependency injection
let container = DependencyContainer.createAsync()
let settingsService = container.settingsService
```

### In Test Code
```swift
// Create services directly or use mocks
let settingsService = SettingsService()  // Real service
// OR
let settingsService = MockSettingsService()  // Local mock
// OR  
let settingsService = DeenAssistUI.MockSettingsService()  // Framework mock
```

## Key Points to Remember

1. **These are NOT Swift modules** - they are directory-based frameworks within the main app
2. **Only import the main app module** in tests: `@testable import DeenBuddy`
3. **Use namespacing** when accessing framework classes: `DeenAssistUI.MockSettingsService`
4. **Framework mocks are preferred** over creating new local mocks
5. **All frameworks are accessible** through the main app module import
6. **Protocol definitions** are in DeenAssistProtocols but accessed through main module

## Migration Notes

- These frameworks are transitioning to Swift packages
- Current structure allows development while migration is in progress
- Once migrated, import patterns will change to proper module imports
- For now, treat as internal frameworks within the main app bundle
