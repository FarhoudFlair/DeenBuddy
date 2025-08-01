# Manual Code Signing Configuration Guide

## Current Status
Your project is currently set to **Automatic** code signing, which doesn't support ActivityKit entitlements properly. We need to switch to **Manual** signing for TestFlight deployment.

## Pre-requisites
Before proceeding, ensure you have completed the provisioning profile setup from `TESTFLIGHT_PROVISIONING_GUIDE.md` and have:
- ✅ `DeenBuddy App Store Profile` installed in Xcode
- ✅ `DeenBuddy Widget App Store Profile` installed in Xcode

## Step 1: Verify Provisioning Profiles in Xcode

1. **Open Xcode** → **Preferences** → **Accounts**
2. Select your Apple ID → **View Details**
3. Look for your new provisioning profiles:
   - `DeenBuddy App Store Profile` (com.deenbuddy.app)
   - `DeenBuddy Widget App Store Profile` (com.deenbuddy.app.PrayerTimesWidget)
4. If not visible, click **Download All Profiles**

## Step 2: Configure Main App Target

1. **Open DeenBuddy.xcodeproj in Xcode**
2. Select **DeenBuddy** project → **DeenBuddy** target
3. Go to **Signing & Capabilities** tab
4. **Uncheck** "Automatically manage signing"
5. **Team**: Select your development team (23TQMQNW28)
6. **Provisioning Profile**: 
   - **Debug**: Select "DeenBuddy App Store Profile" or development profile
   - **Release**: Select "DeenBuddy App Store Profile"

## Step 3: Configure Widget Extension Target

1. Select **PrayerTimesWidgetExtension** target
2. Go to **Signing & Capabilities** tab  
3. **Uncheck** "Automatically manage signing"
4. **Team**: Select your development team (23TQMQNW28)
5. **Provisioning Profile**:
   - **Debug**: Select "DeenBuddy Widget App Store Profile" or development profile
   - **Release**: Select "DeenBuddy Widget App Store Profile"

## Step 4: Verify Capabilities

### Main App (DeenBuddy target):
Ensure these capabilities are present:
- ✅ Live Activities (ActivityKit)
- ✅ Push Notifications  
- ✅ App Groups (group.com.deenbuddy.app)
- ✅ Sign in with Apple
- ✅ Background Modes (Background fetch, Background processing)

### Widget Extension (PrayerTimesWidgetExtension target):
Ensure these capabilities are present:
- ✅ Live Activities (ActivityKit)
- ✅ App Groups (group.com.deenbuddy.app)

## Step 5: Test Build

After configuration, test the build:

```bash
# Test iOS Simulator build (should work with either profile)
xcodebuild -scheme DeenBuddy -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build

# Test iOS Device build (requires proper provisioning)
xcodebuild -scheme DeenBuddy -destination generic/platform=iOS build -allowProvisioningUpdates
```

## Expected Results

✅ **Success Indicators**:
- No provisioning profile errors during build
- ActivityKit entitlements properly included
- Both main app and widget extension build successfully
- "Failed to load Info.plist" error is resolved

❌ **If Build Fails**:
- Check provisioning profile names match exactly
- Verify ActivityKit capability is enabled in Apple Developer Console
- Ensure profiles are installed and visible in Xcode
- Check that bundle IDs match exactly

## Troubleshooting

### "Provisioning profile doesn't include ActivityKit"
- Recreate the provisioning profile in Apple Developer Console
- Ensure "Live Activities" capability is checked when creating profile
- Download and reinstall the profile

### "No matching provisioning profiles found"
- Verify bundle IDs match exactly (com.deenbuddy.app, com.deenbuddy.app.PrayerTimesWidget)
- Check that your development certificate is included in the profile
- Try refreshing profiles in Xcode Preferences

### Widget Extension Build Fails
- Ensure widget extension has its own separate provisioning profile
- Verify the widget bundle ID ends with .PrayerTimesWidget
- Check that App Groups capability is enabled for widget

## Next Steps

Once manual signing is working:
1. Update Fastlane configuration to use manual profiles
2. Test TestFlight deployment
3. Verify ActivityKit functionality in TestFlight builds