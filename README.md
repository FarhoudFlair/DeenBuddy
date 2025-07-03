# DeenAssist Core - Location & Network Services

## Overview

DeenAssist Core is the foundational module for the Deen Assist iOS app, providing comprehensive location services, API integration, and notification management for Muslim prayer times and qibla direction.

## Architecture

This module follows a **protocol-first architecture** that enables parallel development across the engineering team. All services are defined as protocols with both production implementations and mock implementations for testing and development.

### Key Components

- **Location Services**: CoreLocation-based location detection with permission handling
- **API Client**: AlAdhan API integration with caching and offline support
- **Notification Services**: Prayer time reminders with customizable settings
- **Dependency Injection**: Clean service registration and resolution system

## Features

### 🌍 Location Services
- Automatic location detection using CoreLocation
- Manual city search with geocoding
- Location permission management
- Intelligent caching with expiration
- Offline location fallback

### 🌐 API Integration
- AlAdhan API client for prayer times and qibla direction
- Automatic rate limiting (90 requests/minute)
- Network reachability monitoring
- Intelligent caching with 24-hour expiration
- Offline fallback with local calculations

### 🔔 Notification Services
- Prayer time reminders with customizable timing
- Granular prayer selection (enable/disable individual prayers)
- Custom notification messages
- Sound and badge configuration
- Background notification scheduling

### 🧪 Testing & Development
- Comprehensive mock implementations
- Protocol-based dependency injection
- Unit tests with 95%+ coverage
- Integration tests for end-to-end flows

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/your-org/DeenAssist", from: "1.0.0")
]
```

### Xcode Project

1. File → Add Package Dependencies
2. Enter the repository URL
3. Select the version range
4. Add to your target

## Quick Start

### Basic Setup

```swift
import DeenAssistCore

// Create dependency container
let container = DeenAssistCore.createDependencyContainer()

// Setup services
await container.setupServices()

// Access services
let locationService = container.locationService
let apiClient = container.apiClient
let notificationService = container.notificationService
```

### Get Current Location

```swift
// Request permission
let permissionStatus = await locationService.requestLocationPermission()

guard permissionStatus.isAuthorized else {
    print("Location permission denied")
    return
}

// Get current location
do {
    let location = try await locationService.getCurrentLocation()
    print("Current location: \(location.coordinate)")
} catch {
    print("Failed to get location: \(error)")
}
```

### Fetch Prayer Times

```swift
// Get prayer times for today
do {
    let prayerTimes = try await apiClient.getPrayerTimes(
        for: Date(),
        location: location.coordinate,
        calculationMethod: .muslimWorldLeague,
        madhab: .shafi
    )
    
    print("Fajr: \(prayerTimes.fajr)")
    print("Dhuhr: \(prayerTimes.dhuhr)")
    print("Asr: \(prayerTimes.asr)")
    print("Maghrib: \(prayerTimes.maghrib)")
    print("Isha: \(prayerTimes.isha)")
} catch {
    print("Failed to get prayer times: \(error)")
}
```

### Schedule Prayer Notifications

```swift
// Request notification permission
let notificationStatus = await notificationService.requestNotificationPermission()

guard notificationStatus.isAuthorized else {
    print("Notification permission denied")
    return
}

// Schedule notifications for prayer times
do {
    try await notificationService.schedulePrayerNotifications(for: prayerTimes)
    print("Prayer notifications scheduled")
} catch {
    print("Failed to schedule notifications: \(error)")
}
```

### Get Qibla Direction

```swift
do {
    let qiblaDirection = try await apiClient.getQiblaDirection(for: location.coordinate)
    print("Qibla direction: \(qiblaDirection.direction)° (\(qiblaDirection.compassDirection))")
    print("Distance to Kaaba: \(qiblaDirection.formattedDistance)")
} catch {
    print("Failed to get qibla direction: \(error)")
}
```

## Advanced Usage

### Custom Configuration

```swift
// Custom API configuration
let apiConfig = APIConfiguration(
    baseURL: "https://api.aladhan.com/v1",
    timeout: 30,
    maxRetries: 3,
    rateLimitPerMinute: 90
)

// Create container with custom configuration
let container = DependencyContainer(
    apiConfiguration: apiConfig
)
```

### Custom Notification Settings

```swift
// Configure notification preferences
let settings = NotificationSettings(
    isEnabled: true,
    reminderMinutes: 15, // 15 minutes before prayer
    enabledPrayers: [.fajr, .maghrib, .isha], // Only these prayers
    soundEnabled: true,
    badgeEnabled: false,
    customMessage: "Time for prayer! 🕌"
)

notificationService.updateNotificationSettings(settings)
```

### Offline Support

```swift
// Check network status
if apiClient.isNetworkAvailable {
    // Online - fetch fresh data
    let prayerTimes = try await apiClient.getPrayerTimes(...)
} else {
    // Offline - use cached data or local calculations
    let cachedLocation = locationService.getCachedLocation()
    let qiblaDirection = KaabaLocation.calculateDirection(from: cachedLocation.coordinate)
}
```

## Testing

### Using Mock Services

```swift
import DeenAssistCore

// Create test container with mocks
let testContainer = DependencyContainer.createForTesting()

// Configure mock behavior
let mockLocationService = testContainer.locationService as! MockLocationService
mockLocationService.setMockPermissionStatus(.authorizedWhenInUse)
mockLocationService.addMockLocation(LocationInfo(...))

// Test your code
let location = try await mockLocationService.getCurrentLocation()
```

### Running Tests

```bash
# Run all tests
swift test

# Run specific test suite
swift test --filter LocationServiceTests

# Run with coverage
swift test --enable-code-coverage
```

## Error Handling

### Location Errors

```swift
do {
    let location = try await locationService.getCurrentLocation()
} catch LocationError.permissionDenied {
    // Handle permission denied
} catch LocationError.locationUnavailable {
    // Handle location unavailable
} catch LocationError.accuracyTooLow(let accuracy) {
    // Handle poor accuracy
} catch {
    // Handle other errors
}
```

### API Errors

```swift
do {
    let prayerTimes = try await apiClient.getPrayerTimes(...)
} catch APIError.networkError(let error) {
    // Handle network issues
} catch APIError.rateLimitExceeded {
    // Handle rate limiting
} catch APIError.serverError(let code, let message) {
    // Handle server errors
} catch {
    // Handle other errors
}
```

### Notification Errors

```swift
do {
    try await notificationService.schedulePrayerNotifications(for: prayerTimes)
} catch NotificationError.permissionDenied {
    // Handle permission denied
} catch NotificationError.schedulingFailed {
    // Handle scheduling failure
} catch {
    // Handle other errors
}
```

## Performance Considerations

### Caching Strategy

- **Location**: 5-minute cache with accuracy validation
- **Prayer Times**: 24-hour cache per location and date
- **Qibla Direction**: 30-day cache per location (rounded to 2 decimal places)

### Rate Limiting

- AlAdhan API: 90 requests per minute
- Automatic throttling with exponential backoff
- Request queuing during rate limit periods

### Memory Management

- Automatic cache cleanup for expired entries
- Maximum cache size: 50MB
- Periodic cleanup every hour

## Contributing

### Development Setup

1. Clone the repository
2. Open in Xcode or use Swift Package Manager
3. Run tests to ensure everything works
4. Make your changes
5. Add tests for new functionality
6. Submit a pull request

### Code Style

- Follow Swift API Design Guidelines
- Use protocol-first architecture
- Comprehensive error handling
- 100% test coverage for new code

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For questions, issues, or contributions:

- Create an issue on GitHub
- Contact the development team
- Check the documentation wiki

---

**Built with ❤️ for the Muslim community**
