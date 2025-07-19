# Settings Service Rollback Mechanism Implementation

## Issue Description

The `SettingsService.swift` had a critical UI-data inconsistency issue where:

1. **Immediate UI Updates**: Properties like `notificationsEnabled` would post `.settingsDidChange` notification immediately in `didSet`
2. **Async Save Failures**: `saveSettingsAsync()` would fail silently without reverting the UI state
3. **Data Inconsistency**: UI would show the new value while UserDefaults contained the old value
4. **Poor User Experience**: Users would see settings appear to change but not persist

## Solution: Rollback Mechanism

### Core Implementation

Each `@Published` property now implements a rollback mechanism in its `didSet` observer with infinite loop prevention:

```swift
@Published public var notificationsEnabled: Bool = true {
    didSet {
        // Skip observer actions during rollback operations to prevent infinite loops
        guard !isRestoring else { return }
        
        let oldValue = oldValue
        let newValue = notificationsEnabled
        
        // Notify immediately for UI updates
        NotificationCenter.default.post(name: .settingsDidChange, object: self)

        // Debounce the save operation with rollback capability
        saveSettingsAsync(
            rollbackAction: { [weak self] in
                await MainActor.run {
                    // Set guard flag to prevent didSet observer from triggering during rollback
                    self?.isRestoring = true
                    self?.notificationsEnabled = oldValue
                    self?.isRestoring = false
                }
            },
            propertyName: "notificationsEnabled",
            oldValue: oldValue,
            newValue: newValue
        )
    }
}
```

### Enhanced saveSettingsAsync Method

Added an overloaded version that handles rollback:

```swift
private func saveSettingsAsync(
    rollbackAction: @escaping () async -> Void,
    propertyName: String,
    oldValue: Any,
    newValue: Any
) {
    // Cancel any existing save task
    saveTask?.cancel()
    
    // Create a new debounced save task with rollback capability
    saveTask = Task {
        do {
            // Wait for the debounce interval
            try await Task.sleep(nanoseconds: UInt64(saveDebounceInterval * 1_000_000_000))

            // Check if the task was cancelled
            if !Task.isCancelled {
                try await saveSettings()
                print("✅ Successfully saved setting: \(propertyName) = \(newValue)")
            }
        } catch is CancellationError {
            // Handle cancellation gracefully without triggering rollback
            print("ℹ️ Settings save operation for \(propertyName) was cancelled (this is normal for rapid changes)")
        } catch {
            // Handle genuine save errors gracefully
            print("❌ Failed to save settings for \(propertyName): \(error.localizedDescription)")
            print("🔄 Rolling back \(propertyName) from \(newValue) to \(oldValue)")

            // Execute rollback action
            await rollbackAction()

            // Post notification about save failure with rollback info
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .settingsSaveFailed,
                    object: self,
                    userInfo: [
                        "error": error,
                        "propertyName": propertyName,
                        "attemptedValue": newValue,
                        "rolledBackTo": oldValue,
                        "rollbackPerformed": true
                    ]
                )
            }
        }
    }
}
```

### Helper Method

Added `notifyAndSaveSettings` helper to reduce code duplication:

```swift
private func notifyAndSaveSettings(
    rollbackAction: (() async -> Void)? = nil,
    propertyName: String? = nil,
    oldValue: Any? = nil,
    newValue: Any? = nil
) {
    NotificationCenter.default.post(name: .settingsDidChange, object: self)
    if let rollback = rollbackAction, let property = propertyName, let oldVal = oldValue, let newVal = newValue {
        saveSettingsAsync(
            rollbackAction: rollback,
            propertyName: property,
            oldValue: oldVal,
            newValue: newVal
        )
    } else {
        saveSettingsAsync()
    }
}
```

## Properties Updated

All settings properties now use the rollback mechanism:

- ✅ `calculationMethod`
- ✅ `madhab`
- ✅ `notificationsEnabled`
- ✅ `theme`
- ✅ `hasCompletedOnboarding`
- ✅ `userName`
- ✅ `timeFormat`
- ✅ `notificationOffset`
- ✅ `overrideBatteryOptimization`
- ✅ `showArabicSymbolInWidget`

## Infinite Loop Prevention

### Guard Flag Mechanism

To prevent infinite save/rollback loops, each property implements a guard flag mechanism:

```swift
// Private guard flag to suppress didSet observers during rollback operations
private var isRestoring = false
```

**How it works:**
1. **Normal Operation**: `isRestoring` is `false`, so `didSet` observers execute normally
2. **Rollback Operation**: Before assigning the old value, `isRestoring` is set to `true`
3. **Observer Suppression**: The `didSet` observer checks `isRestoring` and returns early if `true`
4. **Flag Reset**: After the rollback assignment, `isRestoring` is reset to `false`

This prevents the rollback assignment from triggering another save operation, breaking the potential infinite loop.

## CancellationError Handling

### Proper Error Classification

The rollback mechanism now properly distinguishes between different types of errors:

```swift
} catch is CancellationError {
    // Handle cancellation gracefully without triggering rollback
    print("ℹ️ Settings save operation for \(propertyName) was cancelled (this is normal for rapid changes)")
} catch {
    // Handle genuine save errors gracefully
    print("❌ Failed to save settings for \(propertyName): \(error.localizedDescription)")
    // ... rollback logic
}
```

**Why this matters:**
1. **Task Cancellation**: When users make rapid changes, previous save tasks are cancelled
2. **No Unnecessary Rollbacks**: CancellationError doesn't indicate a save failure, so no rollback is needed
3. **Better User Experience**: Users don't see their changes reverted when they make rapid adjustments
4. **Performance**: Avoids unnecessary rollback operations for normal cancellation scenarios

**Error Types Handled:**
- **CancellationError**: Normal task cancellation, no rollback needed
- **Genuine Save Errors**: Actual save failures that require rollback
- **Network Errors**: Connection issues that may require retry logic
- **Permission Errors**: Access denied scenarios

## Benefits

### 1. **UI-Data Consistency**
- UI immediately reflects user changes (good UX)
- Settings revert if save fails (data consistency)
- No more phantom setting changes

### 2. **Error Handling**
- `.settingsSaveFailed` notification informs UI of failures
- Detailed failure information for debugging
- Graceful degradation on save errors

### 3. **User Experience**
- Settings always reflect actual persisted state
- No confusion about whether changes were saved
- Immediate visual feedback with reliable persistence

### 4. **Developer Experience**
- Clear error logging with property names and values
- Rollback actions are automatically executed
- Comprehensive notification userInfo for debugging

## Notification Enhancement

The `.settingsSaveFailed` notification now includes:

```swift
userInfo: [
    "error": error,                    // The actual error that occurred
    "propertyName": propertyName,      // Which setting failed to save
    "attemptedValue": newValue,        // What value was attempted
    "rolledBackTo": oldValue,          // What value it was reverted to
    "rollbackPerformed": true          // Confirms rollback was executed
]
```

## Testing

### Unit Tests
- Created `SettingsServiceRollbackTests.swift` to validate rollback behavior
- Tests cover individual property rollbacks and integration scenarios
- Validates notification posting and userInfo content

### Demo Script
- Created `Scripts/test_settings_rollback.swift` to demonstrate the mechanism
- Shows successful saves vs. rollback scenarios
- Illustrates the benefits of the new implementation

## Memory Management

- Uses `[weak self]` in rollback closures to prevent retain cycles
- Properly cancels existing save tasks before creating new ones
- Executes rollback actions on `MainActor` for UI consistency

## Backward Compatibility

- Maintains existing public API
- Preserves all existing functionality
- Only enhances error handling and consistency
- No breaking changes for existing code

## Future Enhancements

1. **Retry Mechanism**: Could add automatic retry on transient failures
2. **Offline Support**: Could queue changes when offline and sync when online
3. **Conflict Resolution**: Could handle concurrent modifications
4. **Analytics**: Could track save failure rates for monitoring

---

**Implementation Date**: July 18, 2025  
**Status**: ✅ Complete and Tested  
**Critical for**: Islamic Prayer App Settings Reliability
