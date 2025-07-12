# UserDefaults Keys Audit - Prayer Time Synchronization Bug

## Critical Issue Identified

**Problem**: PrayerTimeService and SettingsService use different UserDefaults keys for the same settings, causing synchronization failures.

## Current Key Conflicts

### PrayerTimeService (CacheKeys)
Located in: `DeenBuddy/Frameworks/DeenAssistCore/Services/PrayerTimeService.swift`

```swift
private enum CacheKeys {
    static let calculationMethod = "DeenAssist.CalculationMethod"
    static let madhab = "DeenAssist.Madhab"
    static let cachedPrayerTimes = "DeenAssist.CachedPrayerTimes"
    static let cacheDate = "DeenAssist.CacheDate"
}
```

### SettingsService (SettingsKeys)
Located in: `DeenBuddy/Frameworks/DeenAssistCore/Services/SettingsService.swift`

```swift
private enum SettingsKeys {
    static let calculationMethod = "DeenAssist.Settings.CalculationMethod"
    static let madhab = "DeenAssist.Settings.Madhab"
    static let notificationsEnabled = "DeenAssist.Settings.NotificationsEnabled"
    static let theme = "DeenAssist.Settings.Theme"
    static let timeFormat = "DeenAssist.Settings.TimeFormat"
    static let notificationOffset = "DeenAssist.Settings.NotificationOffset"
    static let overrideBatteryOptimization = "DeenAssist.Settings.OverrideBatteryOptimization"
    static let hasCompletedOnboarding = "DeenAssist.Settings.HasCompletedOnboarding"
    static let lastSyncDate = "DeenAssist.Settings.LastSyncDate"
    static let settingsVersion = "DeenAssist.Settings.Version"
}
```

## Key Conflicts Analysis

| Setting | PrayerTimeService Key | SettingsService Key | Conflict |
|---------|----------------------|---------------------|----------|
| Calculation Method | `"DeenAssist.CalculationMethod"` | `"DeenAssist.Settings.CalculationMethod"` | ❌ **CRITICAL** |
| Madhab | `"DeenAssist.Madhab"` | `"DeenAssist.Settings.Madhab"` | ❌ **CRITICAL** |

## Impact Assessment

### Critical Issues
1. **Prayer Time Calculation**: When users change calculation method in UI, it updates SettingsService but PrayerTimeService continues using old values
2. **Madhab Settings**: Asr prayer timing changes don't propagate to calculations
3. **Data Persistence**: Settings appear saved but calculations use different stored values
4. **User Experience**: Settings UI shows one value while calculations use another

### Additional Keys Analysis

#### PrayerTimeService Only
- `cachedPrayerTimes`: Used for caching calculated prayer times
- `cacheDate`: Tracks cache validity date

#### SettingsService Only
- `notificationsEnabled`: Notification preferences
- `theme`: App theme settings
- `timeFormat`: 12/24 hour format preference
- `notificationOffset`: Minutes before prayer for notifications
- `overrideBatteryOptimization`: Battery optimization settings
- `hasCompletedOnboarding`: Onboarding completion status
- `lastSyncDate`: Last settings synchronization timestamp
- `settingsVersion`: Settings schema version for migration

## Unified Key Schema Proposal

### Core Prayer Settings (Shared)
```swift
static let calculationMethod = "DeenAssist.Settings.CalculationMethod"
static let madhab = "DeenAssist.Settings.Madhab"
```

### Cache Keys (PrayerTimeService Only)
```swift
static let cachedPrayerTimes = "DeenAssist.Cache.PrayerTimes"
static let cacheDate = "DeenAssist.Cache.Date"
```

### App Settings (SettingsService Only)
```swift
static let notificationsEnabled = "DeenAssist.Settings.NotificationsEnabled"
static let theme = "DeenAssist.Settings.Theme"
static let timeFormat = "DeenAssist.Settings.TimeFormat"
static let notificationOffset = "DeenAssist.Settings.NotificationOffset"
static let overrideBatteryOptimization = "DeenAssist.Settings.OverrideBatteryOptimization"
static let hasCompletedOnboarding = "DeenAssist.Settings.HasCompletedOnboarding"
static let lastSyncDate = "DeenAssist.Settings.LastSyncDate"
static let settingsVersion = "DeenAssist.Settings.Version"
```

## Migration Strategy

### Phase 1: Create Unified Constants
- Create shared constants file
- Use SettingsService keys as the standard (more comprehensive naming)

### Phase 2: Migration Logic
- Read from old PrayerTimeService keys
- Write to new unified keys
- Preserve user data during transition

### Phase 3: Update Services
- Update both services to use unified keys
- Remove old key constants
- Test synchronization

## Risk Assessment

### Low Risk
- Creating unified constants file
- Documentation and planning

### Medium Risk
- Migration logic implementation
- Service updates (potential breaking changes)

### High Risk
- Data loss during migration
- Service synchronization failures

## Next Steps

1. ✅ Complete this audit
2. Create unified constants file
3. Implement migration logic
4. Update services to use unified keys
5. Test synchronization thoroughly

## Files to Modify

1. **New File**: `DeenBuddy/Frameworks/DeenAssistCore/Constants/UnifiedSettingsKeys.swift`
2. **Modify**: `PrayerTimeService.swift`
3. **Modify**: `SettingsService.swift`
4. **Test**: Both services read/write same UserDefaults values

---

**Audit Completed**: ✅
**Critical Conflicts Identified**: 2 (calculationMethod, madhab)
**Recommended Approach**: Use SettingsService key format as standard
**Migration Required**: Yes, for existing user data
