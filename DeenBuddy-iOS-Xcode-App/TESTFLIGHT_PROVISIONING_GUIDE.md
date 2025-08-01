# TestFlight Provisioning Profile Setup Guide

## Step 1: Apple Developer Console - App IDs

### Main App ID Setup
1. Go to [Apple Developer Console](https://developer.apple.com/account/resources/identifiers/list)
2. Click "+" to create new App ID
3. **Description**: `DeenBuddy Main App`
4. **Bundle ID**: `com.deenbuddy.app` (Explicit)
5. **Capabilities to Enable**:
   - ✅ Live Activities (ActivityKit)
   - ✅ Push Notifications
   - ✅ App Groups
   - ✅ Sign in with Apple
   - ✅ Group Activities
6. Click "Continue" and "Register"

### Widget Extension App ID Setup  
1. Click "+" to create another App ID
2. **Description**: `DeenBuddy Prayer Times Widget`
3. **Bundle ID**: `com.deenbuddy.app.PrayerTimesWidget` (Explicit)
4. **Capabilities to Enable**:
   - ✅ Live Activities (ActivityKit)
   - ✅ App Groups
5. Click "Continue" and "Register"

## Step 2: App Groups Configuration

1. Go to "Identifiers" → "App Groups"
2. Click "+" to create new App Group (if not exists)
3. **Description**: `DeenBuddy App Group`
4. **Identifier**: `group.com.deenbuddy.app`
5. Register the App Group

## Step 3: Provisioning Profiles

### Main App Provisioning Profile
1. Go to "Profiles" section
2. Click "+" to create new profile
3. **Type**: iOS App Development (for testing) or App Store (for TestFlight)
4. **App ID**: Select `com.deenbuddy.app`
5. **Certificates**: Select your development certificate
6. **Devices**: Select test devices (for development profile)
7. **Profile Name**: `DeenBuddy App Store Profile`
8. Generate and Download

### Widget Extension Provisioning Profile
1. Click "+" to create another profile
2. **Type**: iOS App Development or App Store
3. **App ID**: Select `com.deenbuddy.app.PrayerTimesWidget`
4. **Certificates**: Select your development certificate  
5. **Devices**: Select test devices (for development profile)
6. **Profile Name**: `DeenBuddy Widget App Store Profile`
7. Generate and Download

## Step 4: Install Profiles

1. Double-click both downloaded `.mobileprovision` files
2. They will be installed in Xcode automatically
3. Verify installation in Xcode → Preferences → Accounts → View Details

## Step 5: App Store Connect App Creation

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Click "My Apps" → "+" → "New App"
3. **Platform**: iOS
4. **Name**: `DeenBuddy - Islamic Prayer Companion`
5. **Primary Language**: English (U.S.)
6. **Bundle ID**: Select `com.deenbuddy.app`
7. **SKU**: `deenbuddy-ios-2025` (unique identifier)
8. Click "Create"

## Step 6: Basic App Store Connect Configuration

### App Information
1. **Category**: Reference or Lifestyle
2. **Age Rating**: Click "Edit" and answer questionnaire (likely 4+)
3. **App Review Information**: 
   - First Name: [Your Name]
   - Last Name: [Your Last Name]  
   - Phone: [Your Phone]
   - Email: [Your Email]
   - Demo Account: Not required (no login needed)

### TestFlight Setup
1. Go to "TestFlight" tab in your app
2. **Test Information**:
   - Beta App Review Information: "DeenBuddy is an Islamic prayer companion app that provides accurate prayer times, Qibla direction, and prayer guides. No account required - all features work offline."
   - **What to Test**: "Please test prayer time accuracy, widget functionality, and Live Activities for prayer reminders."

## Verification Checklist

After completing the above steps, verify:
- ✅ Both App IDs created with ActivityKit capability
- ✅ App Group configured and associated with both App IDs
- ✅ Both provisioning profiles generated and downloaded
- ✅ Profiles installed in Xcode
- ✅ App Store Connect app created
- ✅ Basic TestFlight configuration completed

## Next Steps

Once you've completed these steps:
1. Confirm both provisioning profiles are visible in Xcode
2. Note down the exact profile names for Xcode configuration
3. We'll then update the Xcode project to use manual signing

## Troubleshooting

**If Live Activities capability is missing:**
- Make sure you have the latest Xcode version
- The capability might appear as "ActivityKit" or "Live Activities"
- Contact Apple Developer Support if the capability doesn't appear

**If App Group setup fails:**
- Ensure the App Group identifier is unique
- Verify your Apple Developer Program membership is active
- Check that you have proper permissions in the developer team