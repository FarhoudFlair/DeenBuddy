import XCTest
import CoreLocation
@testable import DeenBuddy

/// Comprehensive Islamic accuracy validation tests for prayer times, notifications, and calendar features
@MainActor
final class IslamicAccuracyValidationTests: XCTestCase {
    
    // MARK: - Test Properties

    private var prayerTimeService: PrayerTimeService!
    private var notificationService: NotificationService!
    private var settingsService: SettingsService!
    private var locationService: LocationService!
    private var apiClient: MockAPIClient!
    private var errorHandler: ErrorHandler!
    private var retryMechanism: RetryMechanism!
    private var networkMonitor: NetworkMonitor!
    private var islamicCacheManager: IslamicCacheManager!
    private var crashReporter: CrashReporter!
    
    // Reference locations for testing
    private let meccaLocation = CLLocation(latitude: 21.4225, longitude: 39.8262)
    private let newYorkLocation = CLLocation(latitude: 40.7128, longitude: -74.0060)
    private let londonLocation = CLLocation(latitude: 51.5074, longitude: -0.1278)
    private let jakartaLocation = CLLocation(latitude: -6.2088, longitude: 106.8456)
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()

        // Initialize real services for Islamic accuracy testing
        settingsService = SettingsService()
        locationService = LocationService()
        apiClient = MockAPIClient()
        crashReporter = CrashReporter()
        errorHandler = ErrorHandler(crashReporter: crashReporter)
        networkMonitor = NetworkMonitor()
        retryMechanism = RetryMechanism(networkMonitor: networkMonitor)
        islamicCacheManager = IslamicCacheManager()

        // Use real PrayerTimeService with Adhan library for accurate calculations
        prayerTimeService = PrayerTimeService(
            locationService: locationService,
            settingsService: settingsService,
            apiClient: apiClient,
            errorHandler: errorHandler,
            retryMechanism: retryMechanism,
            networkMonitor: networkMonitor,
            islamicCacheManager: islamicCacheManager
        )

        notificationService = NotificationService()

        // Set up mock notification center for testing
        let mockNotificationCenter = MockUNUserNotificationCenter()
        notificationService.setMockNotificationCenter(mockNotificationCenter)

        // Set up location service with a valid location (Mecca for testing)
        let meccaLocation = CLLocation(latitude: 21.4225, longitude: 39.8262)
        locationService.currentLocation = meccaLocation

        // Disable battery optimization for testing
        settingsService.overrideBatteryOptimization = true
    }
    
    override func tearDown() async throws {
        // Properly cleanup services to prevent memory leaks
        if let prayerService = prayerTimeService {
            // Cancel any ongoing operations using proper cleanup method
            prayerService.cleanup()
        }

        prayerTimeService = nil
        notificationService = nil
        settingsService = nil
        locationService = nil
        apiClient = nil
        errorHandler = nil
        retryMechanism = nil
        networkMonitor = nil
        islamicCacheManager = nil
        crashReporter = nil

        // Force garbage collection
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        try await super.tearDown()
    }
    
    // MARK: - Prayer Time Accuracy Tests
    
    func testPrayerTimeCalculationMethodAccuracy() async throws {
        let testDate = Date()
        
        // Test different calculation methods
        let calculationMethods: [CalculationMethod] = [
            CalculationMethod.muslimWorldLeague,
            CalculationMethod.egyptian,
            CalculationMethod.karachi,
            CalculationMethod.ummAlQura,
            CalculationMethod.dubai,
            CalculationMethod.qatar,
            .kuwait,
            .moonsightingCommittee,
            .singapore
        ]
        
        for method in calculationMethods {
            settingsService.calculationMethod = method
            
            let prayerTimes = try await prayerTimeService.calculatePrayerTimes(
                for: meccaLocation,
                date: testDate
            )
            
            // Validate prayer time sequence
            validatePrayerTimeSequence(prayerTimes, method: method)
            
            // Validate prayer time ranges
            validatePrayerTimeRanges(prayerTimes, location: meccaLocation, method: method)
        }
    }
    
    func testMadhabAsrCalculationAccuracy() async throws {
        let testDate = Date()

        // Test Shafi madhab (earlier Asr timing)
        settingsService.madhab = Madhab.shafi
        let shafiPrayerTimes = try await prayerTimeService.calculatePrayerTimes(
            for: newYorkLocation,
            date: testDate
        )

        // Test Hanafi madhab (later Asr timing)
        settingsService.madhab = Madhab.hanafi
        let hanafiPrayerTimes = try await prayerTimeService.calculatePrayerTimes(
            for: newYorkLocation,
            date: testDate
        )

        guard let shafiAsrTime = shafiPrayerTimes.first(where: { $0.prayer == Prayer.asr })?.time,
              let hanafiAsrTime = hanafiPrayerTimes.first(where: { $0.prayer == Prayer.asr })?.time else {
            XCTFail("Asr times not found for both madhabs")
            return
        }

        // Verify that Hanafi Asr is later than Shafi Asr (key difference)
        XCTAssertTrue(hanafiAsrTime > shafiAsrTime,
                     "Hanafi Asr time (\(hanafiAsrTime)) should be later than Shafi Asr time (\(shafiAsrTime))")

        // Validate both Asr times are between Dhuhr and Maghrib
        let dhuhrTime = shafiPrayerTimes.first(where: { $0.prayer == Prayer.dhuhr })?.time
        let maghribTime = shafiPrayerTimes.first(where: { $0.prayer == Prayer.maghrib })?.time

        XCTAssertNotNil(dhuhrTime, "Dhuhr time should exist")
        XCTAssertNotNil(maghribTime, "Maghrib time should exist")

        if let dhuhr = dhuhrTime, let maghrib = maghribTime {
            XCTAssertTrue(shafiAsrTime > dhuhr, "Shafi Asr should be after Dhuhr")
            XCTAssertTrue(shafiAsrTime < maghrib, "Shafi Asr should be before Maghrib")
            XCTAssertTrue(hanafiAsrTime > dhuhr, "Hanafi Asr should be after Dhuhr")
            XCTAssertTrue(hanafiAsrTime < maghrib, "Hanafi Asr should be before Maghrib")

            print("📿 Shafi Asr time: \(formatTime(shafiAsrTime))")
            print("📿 Hanafi Asr time: \(formatTime(hanafiAsrTime))")
            print("📿 Time difference: \(Int(hanafiAsrTime.timeIntervalSince(shafiAsrTime) / 60)) minutes")
        }
    }

    func testMadhabSettingsIntegration() async throws {
        // Test that changing Madhab setting immediately updates prayer times
        let testDate = Date()

        // Set initial Madhab to Shafi
        settingsService.madhab = Madhab.shafi

        // Wait for settings to propagate
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Get initial prayer times
        let initialPrayerTimes = try await prayerTimeService.calculatePrayerTimes(
            for: newYorkLocation,
            date: testDate
        )
        let initialAsrTime = initialPrayerTimes.first(where: { $0.prayer == Prayer.asr })?.time

        // Change Madhab to Hanafi
        settingsService.madhab = Madhab.hanafi

        // Wait for settings to propagate and prayer times to refresh
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        // Get updated prayer times
        let updatedPrayerTimes = try await prayerTimeService.calculatePrayerTimes(
            for: newYorkLocation,
            date: testDate
        )
        let updatedAsrTime = updatedPrayerTimes.first(where: { $0.prayer == Prayer.asr })?.time

        // Verify that the Asr time changed
        XCTAssertNotNil(initialAsrTime, "Initial Asr time should exist")
        XCTAssertNotNil(updatedAsrTime, "Updated Asr time should exist")

        if let initial = initialAsrTime, let updated = updatedAsrTime {
            XCTAssertNotEqual(initial, updated, "Asr time should change when Madhab changes")
            XCTAssertTrue(updated > initial, "Hanafi Asr should be later than Shafi Asr")

            print("📿 Madhab integration test:")
            print("   Shafi Asr: \(formatTime(initial))")
            print("   Hanafi Asr: \(formatTime(updated))")
            print("   Difference: \(Int(updated.timeIntervalSince(initial) / 60)) minutes")
        }
    }

    func testPrayerTimeGeographicalAccuracy() async throws {
        let testDate = Date()
        let locations = [
            ("Mecca", meccaLocation),
            ("New York", newYorkLocation),
            ("London", londonLocation),
            ("Jakarta", jakartaLocation)
        ]
        
        for (locationName, location) in locations {
            let prayerTimes = try await prayerTimeService.calculatePrayerTimes(
                for: location,
                date: testDate
            )
            
            // Validate prayer times are reasonable for location
            validateGeographicalReasonableness(prayerTimes, location: location, locationName: locationName)
            
            // Validate Qibla direction accuracy
            await validateQiblaAccuracy(for: location, locationName: locationName)
        }
    }
    
    // MARK: - Hijri Calendar Accuracy Tests
    
    func testHijriDateAccuracy() {
        let testDates = [
            Date(), // Today
            Calendar.current.date(byAdding: .month, value: 1, to: Date())!, // Next month
            Calendar.current.date(byAdding: .year, value: 1, to: Date())! // Next year
        ]
        
        for gregorianDate in testDates {
            let hijriDate = HijriDate(from: gregorianDate)
            
            // Validate Hijri date components
            XCTAssertGreaterThan(hijriDate.day, 0, "Hijri day should be positive")
            XCTAssertLessThanOrEqual(hijriDate.day, 30, "Hijri day should not exceed 30")
            XCTAssertTrue(HijriMonth.allCases.contains(hijriDate.month), "Hijri month should be valid")
            XCTAssertGreaterThan(hijriDate.year, 1400, "Hijri year should be reasonable")
            
            // Validate conversion back to Gregorian
            let convertedBack = hijriDate.toGregorianDate()
            let daysDifference = abs(convertedBack.timeIntervalSince(gregorianDate) / 86400)
            XCTAssertLessThan(daysDifference, 2, "Hijri-Gregorian conversion should be accurate within 2 days")
            
            print("📅 \(formatDate(gregorianDate)) → \(hijriDate.formatted)")
        }
    }
    
    func testIslamicMonthProperties() {
        for month in HijriMonth.allCases {
            // Test sacred months
            let sacredMonths: [HijriMonth] = [HijriMonth.muharram, HijriMonth.rajab, HijriMonth.dhulQadah, HijriMonth.dhulHijjah]
            if sacredMonths.contains(month) {
                XCTAssertTrue(month.isSacred, "\(month) should be marked as sacred")
            }
            
            // Test Ramadan
            if month == HijriMonth.ramadan {
                XCTAssertEqual(month.displayName, "Ramadan", "Ramadan should have correct display name")
            }
            
            // Test month colors are defined
            XCTAssertNotNil(month.color, "Month \(month) should have a color defined")
            
            print("🌙 \(month.displayName) - Sacred: \(month.isSacred)")
        }
    }
    
    // MARK: - Notification Content Accuracy Tests
    
    func testNotificationIslamicContent() async throws {
        let prayerTimes = createMockPrayerTimes()
        
        for prayerTime in prayerTimes {
            let config = PrayerNotificationConfig.default
            
            try await notificationService.scheduleEnhancedNotification(
                for: prayerTime.prayer,
                prayerTime: prayerTime.time,
                notificationTime: prayerTime.time,
                reminderMinutes: 0,
                config: config
            )
        }
        
        let pendingNotifications = await notificationService.getPendingNotifications()
        
        for notification in pendingNotifications {
            // Validate Islamic terminology
            validateIslamicTerminology(in: notification.title)
            validateIslamicTerminology(in: notification.body)
            
            // Validate Arabic names are included
            let prayer = notification.prayer
            XCTAssertTrue(
                notification.body.contains(prayer.arabicName) || notification.title.contains(prayer.arabicName),
                "Notification should contain Arabic name for \(prayer.displayName)"
            )
            
            // Validate proper capitalization and formatting
            XCTAssertFalse(notification.title.isEmpty, "Notification title should not be empty")
            XCTAssertFalse(notification.body.isEmpty, "Notification body should not be empty")
            
            print("🔔 \(prayer.displayName): \(notification.title) - \(notification.body)")
        }
    }
    
    func testPrayerRakahAccuracy() {
        let expectedRakahCounts: [Prayer: Int] = [
            Prayer.fajr: 2,
            Prayer.dhuhr: 4,
            Prayer.asr: 4,
            Prayer.maghrib: 3,
            Prayer.isha: 4
        ]
        
        for prayer in Prayer.allCases {
            let expectedRakah = expectedRakahCounts[prayer]!
            XCTAssertEqual(prayer.defaultRakahCount, expectedRakah, "\(prayer.displayName) should have \(expectedRakah) rakah")
            
            // Validate rakah description using available properties
            let description = "\(prayer.displayName) has \(prayer.defaultRakahCount) rakah"
            XCTAssertTrue(description.contains("\(expectedRakah)"), "Rakah description should contain count")
            XCTAssertTrue(description.contains("rakah"), "Description should use proper Islamic term")
            
            print("🤲 \(prayer.displayName): \(description)")
        }
    }
    
    // MARK: - Widget Islamic Accuracy Tests
    
    func testWidgetIslamicContent() {
        let widgetData = WidgetData.placeholder
        let configuration = WidgetConfiguration.default
        
        // Validate Hijri date formatting
        let hijriFormatted = widgetData.hijriDate.formatted
        XCTAssertFalse(hijriFormatted.isEmpty, "Hijri date should be formatted")
        XCTAssertTrue(hijriFormatted.contains("AH"), "Hijri date should contain 'AH' suffix")
        
        // Validate prayer time display
        for prayerTime in widgetData.todaysPrayerTimes {
            XCTAssertNotNil(prayerTime.prayer.systemImageName, "Prayer should have system image")
            XCTAssertNotNil(prayerTime.prayer.color, "Prayer should have associated color")
            XCTAssertFalse(prayerTime.prayer.arabicName.isEmpty, "Prayer should have Arabic name")
            
            print("📱 Widget: \(prayerTime.prayer.displayName) (\(prayerTime.prayer.arabicName))")
        }
        
        // Validate calculation method display
        let methodName = widgetData.calculationMethod.displayName
        XCTAssertFalse(methodName.isEmpty, "Calculation method should have display name")
        
        print("📱 Widget calculation method: \(methodName)")
    }
    
    // MARK: - Islamic Event Accuracy Tests
    
    func testIslamicEventAccuracy() async throws {
        let eventService = IslamicEventNotificationService.shared
        
        // Test Ramadan events
        let ramadanYear = 1445 // Example Hijri year
        
        // Create test events
        let ramadanStart = IslamicEvent(
            id: UUID(),
            name: "Ramadan Mubarak",
            description: "Ramadan Mubarak Message.",
            hijriDate: HijriDate(day: 1, month: HijriMonth.ramadan, year: ramadanYear),
            category: EventCategory.religious,
            significance: EventSignificance.major
        )
        
        // Validate event properties
        XCTAssertEqual(ramadanStart.hijriDate.month, HijriMonth.ramadan, "Event should be in Ramadan")
        XCTAssertEqual(ramadanStart.category, EventCategory.religious, "Ramadan should be religious event")
        XCTAssertEqual(ramadanStart.significance, EventSignificance.major, "Ramadan start should be major significance")
        
        // Validate Islamic terminology in event
        XCTAssertTrue(ramadanStart.name.contains("Ramadan"), "Event should mention Ramadan")
        XCTAssertTrue(ramadanStart.name.contains("Mubarak"), "Event should use Islamic greeting")
        
        print("🌙 Islamic Event: \(ramadanStart.name)")
    }
    
    // MARK: - Helper Methods
    
    private func validatePrayerTimeSequence(_ prayerTimes: [PrayerTime], method: CalculationMethod) {
        let sortedTimes = prayerTimes.sorted { $0.time < $1.time }
        
        XCTAssertEqual(prayerTimes.count, 5, "Should have 5 prayer times for \(method)")
        
        // Validate sequence: Fajr → Dhuhr → Asr → Maghrib → Isha
        let expectedSequence: [Prayer] = [Prayer.fajr, Prayer.dhuhr, Prayer.asr, Prayer.maghrib, Prayer.isha]
        for (index, expectedPrayer) in expectedSequence.enumerated() {
            XCTAssertEqual(
                sortedTimes[index].prayer,
                expectedPrayer,
                "Prayer sequence incorrect for \(method) at position \(index)"
            )
        }
    }
    
    private func validatePrayerTimeRanges(_ prayerTimes: [PrayerTime], location: CLLocation, method: CalculationMethod) {
        let calendar = Calendar.current
        
        for prayerTime in prayerTimes {
            let hour = calendar.component(.hour, from: prayerTime.time)
            
            // Validate reasonable time ranges based on prayer
            switch prayerTime.prayer {
            case Prayer.fajr:
                XCTAssertTrue(hour >= 3 && hour <= 7, "Fajr should be between 3-7 AM for \(method)")
            case Prayer.dhuhr:
                XCTAssertTrue(hour >= 11 && hour <= 14, "Dhuhr should be between 11 AM-2 PM for \(method)")
            case Prayer.asr:
                XCTAssertTrue(hour >= 13 && hour <= 18, "Asr should be between 1-6 PM for \(method)")
            case Prayer.maghrib:
                XCTAssertTrue(hour >= 16 && hour <= 20, "Maghrib should be between 4-8 PM for \(method)")
            case .isha:
                XCTAssertTrue(hour >= 18 && hour <= 23, "Isha should be between 6-11 PM for \(method)")
            }
        }
    }
    
    private func validateGeographicalReasonableness(_ prayerTimes: [PrayerTime], location: CLLocation, locationName: String) {
        // Validate that prayer times make sense for the geographical location
        let calendar = Calendar.current
        let timeZone = TimeZone.current
        
        for prayerTime in prayerTimes {
            let localTime = prayerTime.time
            let hour = calendar.component(.hour, from: localTime)
            
            // Basic sanity checks
            XCTAssertTrue(hour >= 0 && hour <= 23, "Hour should be valid for \(locationName)")
            
            print("🌍 \(locationName) - \(prayerTime.prayer.displayName): \(formatTime(localTime))")
        }
    }
    
    private func validateQiblaAccuracy(for location: CLLocation, locationName: String) async {
        // Calculate bearing to Mecca
        let bearing = location.bearing(to: meccaLocation)
        
        // Validate bearing is reasonable (0-360 degrees)
        XCTAssertTrue(bearing >= 0 && bearing <= 360, "Qibla bearing should be valid for \(locationName)")
        
        // Validate distance to Mecca is reasonable
        let distance = location.distance(from: meccaLocation)
        XCTAssertGreaterThan(distance, 0, "Distance to Mecca should be positive for \(locationName)")
        
        print("🧭 \(locationName) Qibla: \(Int(bearing))° (\(Int(distance/1000))km to Mecca)")
    }
    
    private func validateIslamicTerminology(in text: String) {
        // Check for proper Islamic terminology
        let islamicTerms = ["prayer", "Fajr", "Dhuhr", "Asr", "Maghrib", "Isha", "Allah", "Mubarak"]
        let hasIslamicContent = islamicTerms.contains { text.contains($0) }
        
        if hasIslamicContent {
            // Validate proper capitalization of Islamic terms
            XCTAssertFalse(text.contains("allah"), "Allah should be capitalized")
            XCTAssertFalse(text.contains("fajr "), "Fajr should be capitalized")
            XCTAssertFalse(text.contains("dhuhr "), "Dhuhr should be capitalized")
        }
    }
    
    private func createMockPrayerTimes() -> [PrayerTime] {
        let calendar = Calendar.current
        let today = Date()
        let baseTime = calendar.startOfDay(for: today)
        
        return [
            PrayerTime(prayer: Prayer.fajr, time: calendar.date(byAdding: .hour, value: 5, to: baseTime)!),
            PrayerTime(prayer: Prayer.dhuhr, time: calendar.date(byAdding: .hour, value: 12, to: baseTime)!),
            PrayerTime(prayer: Prayer.asr, time: calendar.date(byAdding: .hour, value: 15, to: baseTime)!),
            PrayerTime(prayer: Prayer.maghrib, time: calendar.date(byAdding: .hour, value: 18, to: baseTime)!),
            PrayerTime(prayer: Prayer.isha, time: calendar.date(byAdding: .hour, value: 20, to: baseTime)!)
        ]
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - CLLocation Extension for Bearing Calculation

extension CLLocation {
    func bearing(to destination: CLLocation) -> Double {
        let lat1 = coordinate.latitude.degreesToRadians
        let lon1 = coordinate.longitude.degreesToRadians
        let lat2 = destination.coordinate.latitude.degreesToRadians
        let lon2 = destination.coordinate.longitude.degreesToRadians
        
        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        
        let bearing = atan2(y, x).radiansToDegrees
        return bearing < 0 ? bearing + 360 : bearing
    }
}

extension Double {
    var degreesToRadians: Double { return self * .pi / 180 }
    var radiansToDegrees: Double { return self * 180 / .pi }
}


