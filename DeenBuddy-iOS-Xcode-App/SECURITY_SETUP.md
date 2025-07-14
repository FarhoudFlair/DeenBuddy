# DeenBuddy iOS App - Security Setup Guide

## Overview

This guide provides instructions for securely configuring the DeenBuddy iOS app after the removal of hardcoded API keys from the source code.

## ⚠️ CRITICAL SECURITY NOTICE

**Hardcoded API keys have been removed from the source code for security reasons.**

The app now requires credentials to be stored in the iOS Keychain before it can function. This prevents sensitive credentials from being exposed in version control or source code.

## Development Setup

### Prerequisites

- Xcode 15.2+
- Valid Supabase project credentials
- Environment variables configured

### Step 1: Set Environment Variables

Add these environment variables to your development environment:

```bash
# Development Environment
export SUPABASE_URL_DEV="your-development-supabase-url"
export SUPABASE_ANON_KEY_DEV="your-development-anon-key"

# Production Environment (for deployment)
export SUPABASE_URL_PROD="your-production-supabase-url"
export SUPABASE_ANON_KEY_PROD="your-production-anon-key"
```

### Step 2: Configure Xcode Environment Variables

1. Open your Xcode scheme
2. Go to **Product > Scheme > Edit Scheme**
3. Select **Run** from the left sidebar
4. Go to **Arguments** tab
5. Add environment variables under **Environment Variables**:
   - `SUPABASE_URL_DEV` = `your-development-supabase-url`
   - `SUPABASE_ANON_KEY_DEV` = `your-development-anon-key`

### Step 3: Initial Credential Setup

On first run, the app will attempt to read credentials from environment variables and store them securely in the iOS Keychain.

For development, you can use the `SecureSetup` utility:

```swift
#if DEBUG
let secureSetup = SecureSetup()
try secureSetup.quickDevelopmentSetup()
#endif
```

## Production Deployment

### CI/CD Pipeline Setup

For production deployment, credentials should be injected via your CI/CD pipeline:

```yaml
# Example GitHub Actions
- name: Setup Environment
  env:
    SUPABASE_URL_PROD: ${{ secrets.SUPABASE_URL_PROD }}
    SUPABASE_ANON_KEY_PROD: ${{ secrets.SUPABASE_ANON_KEY_PROD }}
  run: |
    # Your deployment script
```

### Secure Deployment Process

1. **Never commit production credentials to version control**
2. **Use environment variables in your deployment pipeline**
3. **Verify credentials are stored in Keychain before deployment**
4. **Remove SecureSetup utility from production builds**

## Verification

### Check Credential Status

```swift
let secureSetup = SecureSetup()

// Check development credentials
if secureSetup.verifyCredentials(for: .development) {
    print("✅ Development credentials are configured")
} else {
    print("❌ Development credentials are missing")
}

// Check production credentials
if secureSetup.verifyCredentials(for: .production) {
    print("✅ Production credentials are configured")
} else {
    print("❌ Production credentials are missing")
}
```

### App Configuration Status

The `ConfigurationManager` will throw `ConfigurationError.missingRequiredKeys` if required credentials are not found in the Keychain.

## Security Best Practices

### Do's
- ✅ Store credentials in iOS Keychain
- ✅ Use environment variables for development
- ✅ Inject credentials via CI/CD pipeline
- ✅ Verify credentials before deployment
- ✅ Rotate credentials regularly

### Don'ts
- ❌ Commit credentials to version control
- ❌ Hardcode credentials in source code
- ❌ Include credentials in build artifacts
- ❌ Share credentials via insecure channels
- ❌ Use development credentials in production

## Troubleshooting

### Common Issues

1. **App crashes on startup with "Missing required keys"**
   - Solution: Configure environment variables and run initial setup

2. **Credentials not found in Keychain**
   - Solution: Run `SecureSetup.quickDevelopmentSetup()` for development

3. **Environment variables not available**
   - Solution: Check Xcode scheme environment variables configuration

### Error Messages

- `ConfigurationError.missingRequiredKeys`: Credentials not found in Keychain
- `ConfigurationError.keychainError`: Keychain access failed
- `ConfigurationError.environmentNotSupported`: Invalid environment configuration

## Migration from Hardcoded Keys

If you're migrating from the previous version with hardcoded keys:

1. **Immediately rotate all exposed credentials**
2. **Update Supabase project security settings**
3. **Configure new credentials using this guide**
4. **Verify old credentials are no longer functional**

### Credential Rotation Process

**CRITICAL: The following Supabase credentials were exposed in source code and MUST be rotated immediately:**

- **Supabase URL**: `https://hjgwbkcjjclwqamtmhsa.supabase.co`
- **Anon Key**: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhqZ3dia2NqamNsd3FhbXRtaHNhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE1NzQwOTYsImV4cCI6MjA2NzE1MDA5Nn0.pipfeKNNDclXlfOimWQnhkf_VY-YTsV3_vZaoEbWSGM`

**Steps to rotate credentials:**

1. **Log into your Supabase project dashboard**
2. **Go to Settings > API**
3. **Generate new anon/public key**
4. **Update your project's RLS policies if needed**
5. **Configure new credentials using the SecureSetup utility**
6. **Verify the old key is disabled**

### Using SecureSetup for Credential Management

```swift
let secureSetup = SecureSetup()

// Check current status
secureSetup.displayConfigurationStatus()

// Reset and setup new credentials
try secureSetup.resetAndSetup(for: .development)
try secureSetup.resetAndSetup(for: .production)

// Verify new credentials
if secureSetup.verifyCredentials(for: .development) {
    print("✅ Development credentials ready")
}
```

## Contact

For security-related questions or issues, please contact the development team immediately.

---

**Last Updated**: 2025-01-14
**Version**: 1.0
**Security Level**: CRITICAL