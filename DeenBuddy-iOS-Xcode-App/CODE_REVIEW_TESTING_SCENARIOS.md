# DeenBuddy iOS Code Review - Testing Scenarios & Validation Procedures

## Overview

This document provides detailed testing scenarios and validation procedures to accompany the comprehensive code review plan. Each scenario includes specific test cases, expected results, and validation criteria.

## 1. Islamic Functionality Testing Scenarios

### 1.1 Prayer Time Calculation Validation

#### Test Case 1: Madhab Differences in Asr Calculation
```swift
func testAsrCalculationMadhabDifferences() {
    let testLocation = CLLocation(latitude: 40.7128, longitude: -74.0060) // NYC
    let testDate = Date()
    
    // Test Shafi madhab (shadow length = object length + shadow at noon)
    let shafiSettings = PrayerSettings(madhab: .shafi, calculationMethod: .muslimWorldLeague)
    let shafiTimes = calculatePrayerTimes(location: testLocation, date: testDate, settings: shafiSettings)
    
    // Test Hanafi madhab (shadow length = 2 * object length + shadow at noon)
    let hanafiSettings = PrayerSettings(madhab: .hanafi, calculationMethod: .muslimWorldLeague)
    let hanafiTimes = calculatePrayerTimes(location: testLocation, date: testDate, settings: hanafiSettings)
    
    // Hanafi Asr should be later than Shafi Asr
    XCTAssertGreaterThan(hanafiTimes.asr, shafiTimes.asr)
}
```

#### Test Case 2: Calculation Method Variations
```swift
func testCalculationMethodDifferences() {
    let testLocations = [
        ("Mecca", 21.4225, 39.8262),
        ("Cairo", 30.0444, 31.2357),
        ("Istanbul", 41.0082, 28.9784)
    ]
    
    let methods: [CalculationMethod] = [.muslimWorldLeague, .egyptian, .karachi, .northAmerica]
    
    for (name, lat, lon) in testLocations {
        let location = CLLocation(latitude: lat, longitude: lon)
        
        for method in methods {
            let times = calculatePrayerTimes(location: location, method: method)
            
            // Validate prayer order
            XCTAssertLessThan(times.fajr, times.sunrise)
            XCTAssertLessThan(times.sunrise, times.dhuhr)
            XCTAssertLessThan(times.dhuhr, times.asr)
            XCTAssertLessThan(times.asr, times.maghrib)
            XCTAssertLessThan(times.maghrib, times.isha)
            
            print("✅ \(name) - \(method): Valid prayer sequence")
        }
    }
}
```

#### Test Case 3: DST Transition Handling
```swift
func testDSTTransitions() {
    let location = CLLocation(latitude: 40.7128, longitude: -74.0060) // NYC
    
    // Test spring forward (March 2024)
    let springForward = DateComponents(year: 2024, month: 3, day: 10)
    let springDate = Calendar.current.date(from: springForward)!
    
    // Test fall back (November 2024)
    let fallBack = DateComponents(year: 2024, month: 11, day: 3)
    let fallDate = Calendar.current.date(from: fallBack)!
    
    let springTimes = calculatePrayerTimes(location: location, date: springDate)
    let fallTimes = calculatePrayerTimes(location: location, date: fallDate)
    
    // Validate times are in local timezone
    XCTAssertTrue(springTimes.fajr.timeZone == TimeZone.current)
    XCTAssertTrue(fallTimes.fajr.timeZone == TimeZone.current)
}
```

### 1.2 Qibla Compass Accuracy Testing

#### Test Case 1: Known Location Validation
```swift
func testQiblaDirectionAccuracy() {
    let testCases = [
        ("New York", 40.7128, -74.0060, 58.0, 5.0), // Expected ~58°, tolerance ±5°
        ("London", 51.5074, -0.1278, 118.0, 5.0),   // Expected ~118°, tolerance ±5°
        ("Sydney", -33.8688, 151.2093, 277.0, 5.0), // Expected ~277°, tolerance ±5°
        ("Tokyo", 35.6762, 139.6503, 293.0, 5.0)    // Expected ~293°, tolerance ±5°
    ]
    
    for (city, lat, lon, expectedDirection, tolerance) in testCases {
        let location = LocationCoordinate(latitude: lat, longitude: lon)
        let qiblaDirection = QiblaDirection.calculate(from: location)
        
        let difference = abs(qiblaDirection.direction - expectedDirection)
        let normalizedDifference = min(difference, 360 - difference) // Handle wrap-around
        
        XCTAssertLessThanOrEqual(normalizedDifference, tolerance, 
                                "Qibla direction for \(city) is outside tolerance")
        
        print("✅ \(city): Expected \(expectedDirection)°, Got \(qiblaDirection.direction)°")
    }
}
```

#### Test Case 2: Compass Calibration Validation
```swift
func testCompassCalibration() {
    let compassManager = CompassManager(locationService: mockLocationService)
    
    // Test calibration accuracy levels
    let accuracyLevels: [Double] = [-1, 5, 15, 30, 45] // -1 = invalid, others in degrees
    
    for accuracy in accuracyLevels {
        compassManager.headingAccuracy = accuracy
        
        let calibrationStatus = compassManager.getCalibrationStatus()
        
        switch accuracy {
        case -1:
            XCTAssertEqual(calibrationStatus, .invalid)
        case 0..<10:
            XCTAssertEqual(calibrationStatus, .high)
        case 10..<20:
            XCTAssertEqual(calibrationStatus, .medium)
        default:
            XCTAssertEqual(calibrationStatus, .low)
        }
    }
}
```

### 1.3 Hijri Calendar Validation

#### Test Case 1: Known Date Conversions
```swift
func testHijriDateConversions() {
    let knownConversions = [
        // (Gregorian, Expected Hijri)
        (DateComponents(year: 2024, month: 1, day: 1), HijriDate(year: 1445, month: .rajab, day: 19)),
        (DateComponents(year: 2024, month: 3, day: 11), HijriDate(year: 1445, month: .ramadan, day: 1)), // Ramadan start
        (DateComponents(year: 2024, month: 4, day: 10), HijriDate(year: 1445, month: .shawwal, day: 1)), // Eid al-Fitr
        (DateComponents(year: 2024, month: 6, day: 16), HijriDate(year: 1445, month: .dhulHijjah, day: 10)) // Eid al-Adha
    ]
    
    for (gregorianComponents, expectedHijri) in knownConversions {
        let gregorianDate = Calendar.current.date(from: gregorianComponents)!
        let calculatedHijri = HijriDate(from: gregorianDate)
        
        XCTAssertEqual(calculatedHijri.year, expectedHijri.year)
        XCTAssertEqual(calculatedHijri.month, expectedHijri.month)
        XCTAssertLessThanOrEqual(abs(calculatedHijri.day - expectedHijri.day), 1, 
                                "Hijri day calculation within ±1 day tolerance")
    }
}
```

#### Test Case 2: Islamic Event Detection
```swift
func testIslamicEventDetection() {
    let islamicCalendarService = IslamicCalendarService()
    
    // Test major Islamic events
    let testYear = 1445 // Hijri year
    let events = islamicCalendarService.getEventsForYear(testYear)
    
    let expectedEvents = [
        "Ramadan Begins",
        "Laylat al-Qadr",
        "Eid al-Fitr",
        "Hajj Season",
        "Day of Arafah",
        "Eid al-Adha",
        "Islamic New Year",
        "Day of Ashura"
    ]
    
    for expectedEvent in expectedEvents {
        let foundEvent = events.first { $0.name.contains(expectedEvent) }
        XCTAssertNotNil(foundEvent, "Missing Islamic event: \(expectedEvent)")
    }
}
```

## 2. Performance Testing Scenarios

### 2.1 Memory Leak Detection

#### Test Case 1: Service Lifecycle Memory Management
```swift
func testServiceMemoryManagement() {
    weak var weakPrayerService: PrayerTimeService?
    weak var weakLocationService: LocationService?
    weak var weakNotificationService: NotificationService?
    
    autoreleasepool {
        let locationService = LocationService()
        let notificationService = NotificationService()
        let prayerService = PrayerTimeService(
            locationService: locationService,
            settingsService: MockSettingsService(),
            apiClient: MockAPIClient(),
            errorHandler: ErrorHandler(crashReporter: CrashReporter()),
            retryMechanism: RetryMechanism(networkMonitor: NetworkMonitor.shared),
            networkMonitor: NetworkMonitor.shared
        )
        
        weakPrayerService = prayerService
        weakLocationService = locationService
        weakNotificationService = notificationService
        
        // Simulate service usage
        prayerService.refreshPrayerTimes()
        locationService.requestLocationPermission()
        notificationService.requestPermission()
    }
    
    // Services should be deallocated
    XCTAssertNil(weakPrayerService, "PrayerTimeService memory leak detected")
    XCTAssertNil(weakLocationService, "LocationService memory leak detected")
    XCTAssertNil(weakNotificationService, "NotificationService memory leak detected")
}
```

#### Test Case 2: NotificationCenter Observer Cleanup
```swift
func testNotificationObserverCleanup() {
    let initialObserverCount = getNotificationObserverCount()
    
    autoreleasepool {
        let service = PrayerTimeService(/* dependencies */)
        
        // Trigger observer registration
        service.setupSettingsObservers()
        service.setupLocationObserver()
        
        let observerCountAfterSetup = getNotificationObserverCount()
        XCTAssertGreaterThan(observerCountAfterSetup, initialObserverCount)
    }
    
    // Observers should be cleaned up after service deallocation
    let finalObserverCount = getNotificationObserverCount()
    XCTAssertEqual(finalObserverCount, initialObserverCount, 
                   "NotificationCenter observers not properly cleaned up")
}
```

### 2.2 UI Performance Testing

#### Test Case 1: Prayer Time Calculation Performance
```swift
func testPrayerTimeCalculationPerformance() {
    let location = CLLocation(latitude: 40.7128, longitude: -74.0060)
    let prayerService = PrayerTimeService(/* dependencies */)
    
    measure {
        for _ in 0..<100 {
            _ = prayerService.calculatePrayerTimes(for: location, date: Date())
        }
    }
    
    // Should complete 100 calculations in under 1 second
    XCTAssertLessThan(measurementTime, 1.0)
}
```

#### Test Case 2: UI Responsiveness During Background Tasks
```swift
func testUIResponsivenessDuringBackgroundTasks() {
    let expectation = XCTestExpectation(description: "Background task completion")
    
    // Start background prayer time refresh
    backgroundPrayerRefreshService.performBackgroundRefresh()
    
    // Measure UI responsiveness
    let startTime = CFAbsoluteTimeGetCurrent()
    
    DispatchQueue.main.async {
        // Simulate UI interaction
        let endTime = CFAbsoluteTimeGetCurrent()
        let responseTime = endTime - startTime
        
        XCTAssertLessThan(responseTime, 0.1, "UI blocked during background task")
        expectation.fulfill()
    }
    
    wait(for: [expectation], timeout: 5.0)
}
```

## 3. Security Testing Scenarios

### 3.1 API Key Security Validation

#### Test Case 1: Hardcoded Credential Detection
```swift
func testNoHardcodedCredentials() {
    let sourceFiles = getAllSourceFiles()
    let suspiciousPatterns = [
        "api_key\\s*=\\s*[\"'][^\"']+[\"']",
        "password\\s*=\\s*[\"'][^\"']+[\"']",
        "secret\\s*=\\s*[\"'][^\"']+[\"']",
        "token\\s*=\\s*[\"'][^\"']+[\"']"
    ]
    
    for file in sourceFiles {
        let content = try! String(contentsOfFile: file)
        
        for pattern in suspiciousPatterns {
            let regex = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
            
            XCTAssertEqual(matches.count, 0, 
                          "Potential hardcoded credential found in \(file)")
        }
    }
}
```

### 3.2 Data Storage Security

#### Test Case 1: Sensitive Data Encryption
```swift
func testSensitiveDataEncryption() {
    let prayerTrackingService = PrayerTrackingService(/* dependencies */)
    
    // Store sensitive prayer data
    let prayerEntry = PrayerEntry(
        prayer: .fajr,
        completedAt: Date(),
        location: "Test Mosque",
        notes: "Personal reflection"
    )
    
    prayerTrackingService.logPrayerCompletion(prayerEntry)
    
    // Verify data is not stored in plain text
    let userDefaults = UserDefaults.standard
    let storedData = userDefaults.data(forKey: "prayer_entries")
    
    if let data = storedData {
        let dataString = String(data: data, encoding: .utf8)
        XCTAssertNil(dataString, "Prayer data should be encrypted, not plain text")
    }
}
```

## 4. Integration Testing Scenarios

### 4.1 End-to-End Prayer Time Synchronization

#### Test Case 1: Complete Prayer Time Flow
```swift
func testEndToEndPrayerTimeSynchronization() async {
    let expectation = XCTestExpectation(description: "Prayer time synchronization")
    
    // 1. Update settings
    settingsService.calculationMethod = .muslimWorldLeague
    settingsService.madhab = .shafi
    
    // 2. Trigger location update
    locationService.mockLocation = CLLocation(latitude: 40.7128, longitude: -74.0060)
    
    // 3. Refresh prayer times
    await prayerTimeService.refreshPrayerTimes()
    
    // 4. Verify UI updates
    XCTAssertFalse(prayerTimeService.todaysPrayerTimes.isEmpty)
    XCTAssertNotNil(prayerTimeService.nextPrayer)
    
    // 5. Verify notifications scheduled
    let pendingNotifications = await notificationService.getPendingNotifications()
    XCTAssertEqual(pendingNotifications.count, 5) // 5 daily prayers
    
    // 6. Verify cache consistency
    let cachedTimes = apiCache.getCachedPrayerTimes(for: Date())
    XCTAssertEqual(cachedTimes?.count, prayerTimeService.todaysPrayerTimes.count)
    
    expectation.fulfill()
    await fulfillment(of: [expectation], timeout: 10.0)
}
```

## 5. Accessibility Testing Scenarios

### 5.1 VoiceOver Compatibility

#### Test Case 1: Islamic Feature Accessibility
```swift
func testIslamicFeatureAccessibility() {
    let homeScreen = HomeScreen(/* dependencies */)
    
    // Test prayer time accessibility
    let prayerTimeCards = homeScreen.prayerTimesSection
    for card in prayerTimeCards {
        XCTAssertNotNil(card.accessibilityLabel)
        XCTAssertNotNil(card.accessibilityValue)
        XCTAssertTrue(card.isAccessibilityElement)
    }
    
    // Test Qibla compass accessibility
    let qiblaCompass = QiblaCompassScreen(/* dependencies */)
    XCTAssertNotNil(qiblaCompass.accessibilityLabel)
    XCTAssertEqual(qiblaCompass.accessibilityTraits, .button)
}
```

## 6. Validation Criteria

### 6.1 Islamic Accuracy Standards
- Prayer time calculations within ±2 minutes of authoritative sources
- Qibla direction accuracy within ±5 degrees
- Hijri date conversion within ±1 day tolerance
- Islamic event dates match recognized Islamic authorities

### 6.2 Performance Standards
- Prayer time calculation: <100ms per calculation
- UI responsiveness: <16ms frame time (60 FPS)
- Memory usage: <50MB baseline, <100MB peak
- App launch time: <3 seconds cold start

### 6.3 Security Standards
- No hardcoded credentials in source code
- Sensitive data encrypted at rest
- HTTPS for all network communications
- Privacy compliance for location and user data

### 6.4 Quality Standards
- Code coverage: >80% for Islamic services
- Zero critical static analysis warnings
- All Islamic terminology culturally appropriate
- Consistent error handling patterns

## Test Execution Guidelines

1. **Automated Tests**: Run as part of CI/CD pipeline
2. **Manual Tests**: Execute on physical devices with different locations
3. **Performance Tests**: Use Instruments for memory and performance profiling
4. **Security Tests**: Use static analysis tools and manual code review
5. **Islamic Validation**: Consult with Islamic scholars for religious accuracy

---

**Document Version**: 1.0  
**Last Updated**: 2025-01-14  
**Testing Team**: QA Team, Development Team  
**Islamic Validation**: Islamic Advisory Board
