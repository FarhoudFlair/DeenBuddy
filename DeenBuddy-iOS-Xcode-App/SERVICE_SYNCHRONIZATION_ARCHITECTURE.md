# Service Synchronization Architecture Design

## Overview

This document outlines the architecture for synchronizing settings between `SettingsService` and `PrayerTimeService` to fix the critical prayer time calculation bug.

## Problem Statement

Currently, `SettingsService` and `PrayerTimeService` operate independently with duplicate settings properties and different UserDefaults keys. This causes:

1. UI changes in settings don't trigger prayer time recalculation
2. Prayer times continue using old calculation methods
3. Inconsistent state between services

## Architectural Approaches Considered

### Option 1: Observer Pattern (CHOSEN)
**Description**: PrayerTimeService observes SettingsService changes using Combine publishers.

**Pros**:
- Clean separation of concerns
- Reactive updates
- Minimal coupling
- Easy to test

**Cons**:
- Requires careful memory management
- Potential for retain cycles

### Option 2: Shared State Manager
**Description**: Create a central state manager that both services reference.

**Pros**:
- Single source of truth
- Centralized state management

**Cons**:
- Adds complexity
- Requires major refactoring
- Breaks existing patterns

### Option 3: Direct Dependency Injection
**Description**: Inject SettingsService directly into PrayerTimeService.

**Pros**:
- Simple implementation
- Clear dependencies

**Cons**:
- Tight coupling
- Harder to test
- Violates single responsibility

## Chosen Architecture: Observer Pattern

### Design Principles

1. **Single Source of Truth**: SettingsService owns all settings data
2. **Reactive Updates**: PrayerTimeService reacts to SettingsService changes
3. **Loose Coupling**: Services communicate through well-defined interfaces
4. **Testability**: Easy to mock and test interactions

### Implementation Strategy

#### Phase 1: Remove Duplicate Properties
- Remove `calculationMethod` and `madhab` from PrayerTimeService
- Update PrayerTimeService to read from SettingsService

#### Phase 2: Implement Observers
- Add Combine observers in PrayerTimeService
- Subscribe to SettingsService property changes
- Trigger prayer time recalculation on changes

#### Phase 3: Update Dependency Injection
- Inject SettingsService into PrayerTimeService
- Update DependencyContainer configuration

### Detailed Implementation

#### 1. Updated PrayerTimeService Interface

```swift
public class PrayerTimeService: PrayerTimeServiceProtocol, ObservableObject {
    // Remove these properties:
    // @Published public var calculationMethod: CalculationMethod
    // @Published public var madhab: Madhab
    
    // Add dependency:
    private let settingsService: any SettingsServiceProtocol
    
    // Computed properties for backward compatibility:
    public var calculationMethod: CalculationMethod {
        settingsService.calculationMethod
    }
    
    public var madhab: Madhab {
        settingsService.madhab
    }
}
```

#### 2. Observer Implementation

```swift
private func observeSettingsChanges() {
    // Observe calculation method changes
    settingsService.$calculationMethod
        .dropFirst()
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            Task {
                await self?.invalidateCacheAndRefresh()
            }
        }
        .store(in: &cancellables)
    
    // Observe madhab changes
    settingsService.$madhab
        .dropFirst()
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            Task {
                await self?.invalidateCacheAndRefresh()
            }
        }
        .store(in: &cancellables)
}
```

#### 3. Cache Invalidation

```swift
private func invalidateCacheAndRefresh() async {
    // Clear cached prayer times
    clearCachedPrayerTimes()
    
    // Recalculate prayer times with new settings
    await refreshPrayerTimes()
}

private func clearCachedPrayerTimes() {
    let allKeys = userDefaults.dictionaryRepresentation().keys
    let cachePrefix = UnifiedSettingsKeys.cachedPrayerTimes + "_"
    
    for key in allKeys {
        if key.hasPrefix(cachePrefix) {
            userDefaults.removeObject(forKey: key)
        }
    }
    
    userDefaults.removeObject(forKey: UnifiedSettingsKeys.cacheDate)
    userDefaults.synchronize()
}
```

#### 4. Updated Dependency Injection

```swift
public static func createPrayerTimeService(
    locationService: any LocationServiceProtocol,
    settingsService: any SettingsServiceProtocol,
    errorHandler: ErrorHandler,
    retryMechanism: RetryMechanism,
    networkMonitor: NetworkMonitor
) -> any PrayerTimeServiceProtocol {
    return PrayerTimeService(
        locationService: locationService,
        settingsService: settingsService,
        errorHandler: errorHandler,
        retryMechanism: retryMechanism,
        networkMonitor: networkMonitor
    )
}
```

### Protocol Updates

#### PrayerTimeServiceProtocol Changes

```swift
@MainActor
public protocol PrayerTimeServiceProtocol: ObservableObject {
    // Remove these properties:
    // var calculationMethod: CalculationMethod { get set }
    // var madhab: Madhab { get set }
    
    // Add read-only computed properties:
    var calculationMethod: CalculationMethod { get }
    var madhab: Madhab { get }
    
    // Rest of protocol remains the same...
}
```

### Migration Strategy

#### Backward Compatibility
- Maintain computed properties for `calculationMethod` and `madhab`
- Update all references to use read-only access
- Remove setter usage throughout codebase

#### Testing Strategy
- Unit tests for observer functionality
- Integration tests for end-to-end flow
- Mock services for isolated testing

### Benefits of This Architecture

1. **Immediate Synchronization**: Changes in SettingsService immediately trigger updates in PrayerTimeService
2. **Cache Invalidation**: Old cached prayer times are cleared when settings change
3. **Single Source of Truth**: SettingsService is the authoritative source for all settings
4. **Reactive Design**: Uses Combine for clean, reactive programming
5. **Testability**: Easy to test with mock services
6. **Performance**: Only recalculates when necessary

### Risk Mitigation

1. **Memory Leaks**: Use `[weak self]` in closures and proper cancellable management
2. **Infinite Loops**: Use `dropFirst()` to avoid initial value triggers
3. **Threading**: Ensure all UI updates happen on main thread
4. **Error Handling**: Graceful handling of observer failures

### Implementation Order

1. ✅ Update PrayerTimeService constructor to accept SettingsService
2. ✅ Remove duplicate properties from PrayerTimeService
3. ✅ Add computed properties for backward compatibility
4. ✅ Implement observer methods
5. ✅ Update dependency injection container
6. ✅ Test synchronization functionality

### Success Criteria

- [ ] Settings changes in UI immediately trigger prayer time recalculation
- [ ] Cached prayer times are invalidated when calculation methods change
- [ ] No duplicate settings storage or management
- [ ] All tests pass
- [ ] No performance regression

---

**Architecture Decision**: Observer Pattern with SettingsService as single source of truth
**Implementation Approach**: Gradual migration with backward compatibility
**Risk Level**: Medium (requires careful observer management)
**Expected Outcome**: Complete synchronization between services
