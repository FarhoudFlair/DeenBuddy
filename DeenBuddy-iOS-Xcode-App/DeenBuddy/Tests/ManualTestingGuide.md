# Manual Testing Guide for Prayer Time Synchronization Fix

## Overview
This guide provides comprehensive manual testing scenarios to verify that the prayer time synchronization bug has been fixed and that prayer times are accurately calculated across different calculation methods and madhabs.

## Test Environment Setup

### Prerequisites
1. Physical iOS device or simulator
2. Location services enabled
3. Network connectivity
4. Fresh app installation (to test migration scenarios)

### Test Locations
Use these real-world locations for testing:

1. **New York, USA** (40.7128, -74.0060)
2. **Mecca, Saudi Arabia** (21.4225, 39.8262)
3. **London, UK** (51.5074, -0.1278)
4. **Jakarta, Indonesia** (-6.2088, 106.8456)
5. **Cairo, Egypt** (30.0444, 31.2357)

### Test Dates
Test with these specific dates to cover various scenarios:

1. **Summer Solstice**: June 21, 2024
2. **Winter Solstice**: December 21, 2024
3. **Spring Equinox**: March 20, 2024
4. **Fall Equinox**: September 22, 2024
5. **Current Date**: Today's date

## Test Scenarios

### Scenario 1: Basic Settings Synchronization

**Objective**: Verify that changing calculation method updates prayer times immediately.

**Steps**:
1. Open the app and navigate to Settings
2. Set location to New York, USA
3. Set calculation method to "Muslim World League"
4. Note the prayer times displayed
5. Change calculation method to "Egyptian General Authority"
6. Verify prayer times update immediately
7. Change to "University of Islamic Sciences, Karachi"
8. Verify prayer times update again

**Expected Results**:
- Prayer times should change immediately when calculation method is changed
- No app restart should be required
- Times should be different for each calculation method
- UI should reflect changes without delay

### Scenario 2: Madhab Settings Impact

**Objective**: Verify that madhab changes affect Asr prayer time calculation.

**Steps**:
1. Set location to Cairo, Egypt
2. Set calculation method to "Muslim World League"
3. Set madhab to "Shafi"
4. Note the Asr prayer time
5. Change madhab to "Hanafi"
6. Verify Asr prayer time changes (should be later for Hanafi)
7. Change back to "Shafi"
8. Verify Asr time reverts to original

**Expected Results**:
- Asr time should be different between Shafi and Hanafi madhabs
- Hanafi Asr time should typically be later than Shafi
- Other prayer times should remain the same
- Changes should be immediate

### Scenario 3: Cache Invalidation Testing

**Objective**: Verify that cached prayer times are properly invalidated when settings change.

**Steps**:
1. Set location to London, UK
2. Set calculation method to "Muslim World League"
3. Wait for prayer times to load and cache
4. Turn off network connectivity
5. Restart the app (prayer times should load from cache)
6. Turn on network connectivity
7. Change calculation method to "Egyptian General Authority"
8. Verify new prayer times load (not cached old ones)

**Expected Results**:
- App should work offline with cached data
- Changing settings should invalidate cache
- New prayer times should be fetched/calculated with new method
- No stale data should be displayed

### Scenario 4: Background App Refresh

**Objective**: Verify that background updates use current settings.

**Steps**:
1. Set location to Jakarta, Indonesia
2. Set calculation method to "Muslim World League"
3. Enable background app refresh
4. Put app in background
5. Change device time to next day
6. Bring app to foreground
7. Change calculation method to "University of Islamic Sciences, Karachi"
8. Verify prayer times update correctly

**Expected Results**:
- Background refresh should use current settings
- Prayer times should be accurate for new date and method
- No inconsistencies between foreground and background calculations

### Scenario 5: Multiple Rapid Changes

**Objective**: Test system stability under rapid settings changes.

**Steps**:
1. Set location to Mecca, Saudi Arabia
2. Rapidly change calculation method 10 times:
   - Muslim World League → Egyptian → Karachi → Umm Al-Qura → Muslim World League (repeat)
3. Rapidly change madhab 5 times:
   - Shafi → Hanafi → Shafi → Hanafi → Shafi
4. Verify final prayer times are correct for final settings

**Expected Results**:
- App should remain stable and responsive
- Final prayer times should match final settings
- No crashes or UI freezing
- Memory usage should remain reasonable

## Validation Criteria

### Prayer Time Accuracy
Compare calculated prayer times with reliable sources:

1. **IslamicFinder.org**
2. **Pray Times API**
3. **Local mosque prayer schedules**
4. **Islamic Society of North America (ISNA) times**

### Acceptable Variance
- **±2 minutes** for Fajr, Maghrib, Isha
- **±3 minutes** for Dhuhr, Asr
- **±1 minute** for Sunrise

### Performance Benchmarks
- Settings change response: **< 500ms**
- Prayer time calculation: **< 2 seconds**
- Cache invalidation: **< 1 second**
- App startup with cached data: **< 3 seconds**

## Test Data Recording

For each test scenario, record:

```
Date: ___________
Location: ___________
Calculation Method: ___________
Madhab: ___________

Prayer Times:
- Fajr: ___________
- Sunrise: ___________
- Dhuhr: ___________
- Asr: ___________
- Maghrib: ___________
- Isha: ___________

Response Time: ___________
Issues Found: ___________
```

## Known Differences Between Calculation Methods

### Muslim World League vs Egyptian
- **Fajr**: Egyptian typically 1-2 minutes earlier
- **Isha**: Egyptian typically 1-2 minutes later

### Shafi vs Hanafi Madhab
- **Asr**: Hanafi typically 30-60 minutes later than Shafi
- **Other prayers**: No difference

### High Latitude Considerations
For locations above 48° latitude:
- Some methods may use midnight/middle of night rules
- Extreme summer/winter variations expected
- Test with locations like Oslo, Norway (59.9139° N)

## Regression Testing Checklist

After completing manual tests, verify:

- [ ] All calculation methods work correctly
- [ ] Both madhabs calculate Asr properly
- [ ] Settings persist across app restarts
- [ ] Cache invalidation works properly
- [ ] Background refresh uses current settings
- [ ] Migration from old settings works
- [ ] Performance meets benchmarks
- [ ] No memory leaks detected
- [ ] UI remains responsive
- [ ] Accessibility features work

## Troubleshooting Common Issues

### Prayer Times Not Updating
1. Check network connectivity
2. Verify location permissions
3. Clear app cache and restart
4. Check for calculation method conflicts

### Incorrect Prayer Times
1. Verify location accuracy
2. Compare with multiple reliable sources
3. Check for daylight saving time issues
4. Validate calculation method selection

### Performance Issues
1. Monitor memory usage
2. Check for excessive network requests
3. Verify cache efficiency
4. Profile app with Instruments

## Reporting Issues

When reporting issues, include:

1. **Device Information**: Model, iOS version
2. **App Version**: Build number and version
3. **Location**: Exact coordinates used
4. **Settings**: Calculation method and madhab
5. **Expected vs Actual**: Prayer times comparison
6. **Steps to Reproduce**: Detailed reproduction steps
7. **Screenshots**: UI state and prayer times
8. **Logs**: Console output if available

## Sign-off

**Tester Name**: ___________
**Date**: ___________
**Test Results**: PASS / FAIL
**Notes**: ___________

---

*This manual testing guide ensures comprehensive validation of the prayer time synchronization fix across real-world scenarios and edge cases.*
