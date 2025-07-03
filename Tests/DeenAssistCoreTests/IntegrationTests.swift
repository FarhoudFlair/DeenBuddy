import XCTest
import Combine
@testable import DeenAssistCore

final class IntegrationTests: XCTestCase {
    var dependencyContainer: DependencyContainer!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        dependencyContainer = DependencyContainer.createForTesting()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        dependencyContainer = nil
        super.tearDown()
    }
    
    // MARK: - End-to-End Prayer Time Flow
    
    func testCompleteUserFlow_GetPrayerTimesAndScheduleNotifications() async throws {
        // Given - User opens app and grants permissions
        let locationService = dependencyContainer.locationService as! MockLocationService
        let apiClient = dependencyContainer.apiClient as! MockAPIClient
        let notificationService = dependencyContainer.notificationService as! MockNotificationService
        
        // Setup permissions
        locationService.setMockPermissionStatus(.authorizedWhenInUse)
        notificationService.setMockPermissionStatus(.authorized)
        apiClient.setNetworkAvailable(true)
        
        // When - User requests current location
        let location = try await locationService.getCurrentLocation()
        
        // Then - Location should be available
        XCTAssertNotNil(location)
        
        // When - App fetches prayer times for today
        let prayerTimes = try await apiClient.getPrayerTimes(
            for: Date(),
            location: location.coordinate,
            calculationMethod: .muslimWorldLeague,
            madhab: .shafi
        )
        
        // Then - Prayer times should be valid
        XCTAssertEqual(prayerTimes.location.latitude, location.coordinate.latitude, accuracy: 0.001)
        XCTAssertLessThan(prayerTimes.fajr, prayerTimes.dhuhr)
        XCTAssertLessThan(prayerTimes.dhuhr, prayerTimes.asr)
        XCTAssertLessThan(prayerTimes.asr, prayerTimes.maghrib)
        XCTAssertLessThan(prayerTimes.maghrib, prayerTimes.isha)
        
        // When - App schedules notifications
        try await notificationService.schedulePrayerNotifications(for: prayerTimes)
        
        // Then - Notifications should be scheduled
        let pendingNotifications = await notificationService.getPendingNotifications()
        XCTAssertEqual(pendingNotifications.count, Prayer.allCases.count)
        
        // When - User checks qibla direction
        let qiblaDirection = try await apiClient.getQiblaDirection(for: location.coordinate)
        
        // Then - Qibla direction should be valid
        XCTAssertGreaterThan(qiblaDirection.direction, 0)
        XCTAssertLessThan(qiblaDirection.direction, 360)
        XCTAssertGreaterThan(qiblaDirection.distance, 0)
    }
    
    // MARK: - Offline Scenario Tests
    
    func testOfflineScenario_LocationAndPrayerTimes() async throws {
        // Given - User is offline but has cached data
        let locationService = dependencyContainer.locationService as! MockLocationService
        let apiClient = dependencyContainer.apiClient as! MockAPIClient
        
        locationService.setMockPermissionStatus(.authorizedWhenInUse)
        
        // First, get location and prayer times while online
        apiClient.setNetworkAvailable(true)
        let location = try await locationService.getCurrentLocation()
        let onlinePrayerTimes = try await apiClient.getPrayerTimes(
            for: Date(),
            location: location.coordinate,
            calculationMethod: .muslimWorldLeague,
            madhab: .shafi
        )
        
        // When - Network becomes unavailable
        apiClient.setNetworkAvailable(false)
        
        // Then - Cached location should still be available
        let cachedLocation = locationService.getCachedLocation()
        XCTAssertNotNil(cachedLocation)
        XCTAssertEqual(cachedLocation?.coordinate.latitude, location.coordinate.latitude, accuracy: 0.001)
        
        // Then - Cached prayer times should still be available
        let cachedPrayerTimes = try await apiClient.getPrayerTimes(
            for: Date(),
            location: location.coordinate,
            calculationMethod: .muslimWorldLeague,
            madhab: .shafi
        )
        XCTAssertEqual(cachedPrayerTimes.fajr, onlinePrayerTimes.fajr)
        
        // Then - Qibla direction should fallback to local calculation
        let qiblaDirection = try await apiClient.getQiblaDirection(for: location.coordinate)
        XCTAssertGreaterThan(qiblaDirection.direction, 0)
        XCTAssertLessThan(qiblaDirection.direction, 360)
    }
    
    // MARK: - Permission Denied Scenarios
    
    func testPermissionDeniedScenario() async {
        // Given - User denies location permission
        let locationService = dependencyContainer.locationService as! MockLocationService
        let notificationService = dependencyContainer.notificationService as! MockNotificationService
        
        locationService.setMockPermissionStatus(.denied)
        notificationService.setMockPermissionStatus(.denied)
        
        // When - App tries to get location
        do {
            _ = try await locationService.getCurrentLocation()
            XCTFail("Expected LocationError.permissionDenied")
        } catch LocationError.permissionDenied {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        
        // When - App tries to schedule notifications
        let mockPrayerTimes = createMockPrayerTimes()
        do {
            try await notificationService.schedulePrayerNotifications(for: mockPrayerTimes)
            XCTFail("Expected NotificationError.permissionDenied")
        } catch NotificationError.permissionDenied {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Rate Limiting Scenario
    
    func testRateLimitingScenario() async throws {
        // Given - API client with rate limiting
        let apiClient = dependencyContainer.apiClient as! MockAPIClient
        let locationService = dependencyContainer.locationService as! MockLocationService
        
        locationService.setMockPermissionStatus(.authorizedWhenInUse)
        apiClient.setNetworkAvailable(true)
        
        let location = try await locationService.getCurrentLocation()
        
        // When - Rate limit is exceeded
        apiClient.setRateLimited(true)
        
        // Then - API calls should fail with rate limit error
        do {
            _ = try await apiClient.getPrayerTimes(
                for: Date(),
                location: location.coordinate,
                calculationMethod: .muslimWorldLeague,
                madhab: .shafi
            )
            XCTFail("Expected APIError.rateLimitExceeded")
        } catch APIError.rateLimitExceeded {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Service Integration Tests
    
    func testServiceRegistrationAndResolution() {
        // Given - Custom services
        let customLocationService = MockLocationService()
        let customAPIClient = MockAPIClient()
        let customNotificationService = MockNotificationService()
        
        // When - Register custom services
        dependencyContainer.register(service: customLocationService, for: LocationServiceProtocol.self)
        dependencyContainer.register(service: customAPIClient, for: APIClientProtocol.self)
        dependencyContainer.register(service: customNotificationService, for: NotificationServiceProtocol.self)
        
        // Then - Services should be resolved correctly
        let resolvedLocationService = dependencyContainer.resolve(LocationServiceProtocol.self)
        let resolvedAPIClient = dependencyContainer.resolve(APIClientProtocol.self)
        let resolvedNotificationService = dependencyContainer.resolve(NotificationServiceProtocol.self)
        
        XCTAssertTrue(resolvedLocationService === customLocationService)
        XCTAssertTrue(resolvedAPIClient === customAPIClient)
        XCTAssertTrue(resolvedNotificationService === customNotificationService)
    }
    
    func testServiceFactoryCreation() {
        // When - Create services using factory
        let locationService = ServiceFactory.createLocationService(isTest: true)
        let apiClient = ServiceFactory.createAPIClient(isTest: true)
        let notificationService = ServiceFactory.createNotificationService(isTest: true)
        
        // Then - Should create mock services for testing
        XCTAssertTrue(locationService is MockLocationService)
        XCTAssertTrue(apiClient is MockAPIClient)
        XCTAssertTrue(notificationService is MockNotificationService)
    }
    
    // MARK: - Data Flow Integration Tests
    
    func testLocationToQiblaDirectionFlow() async throws {
        // Given
        let locationService = dependencyContainer.locationService as! MockLocationService
        let apiClient = dependencyContainer.apiClient as! MockAPIClient
        
        locationService.setMockPermissionStatus(.authorizedWhenInUse)
        apiClient.setNetworkAvailable(true)
        
        // When - Get location and calculate qibla
        let location = try await locationService.getCurrentLocation()
        let qiblaDirection = try await apiClient.getQiblaDirection(for: location.coordinate)
        
        // Then - Qibla direction should be calculated from location
        XCTAssertEqual(qiblaDirection.location.latitude, location.coordinate.latitude, accuracy: 0.001)
        XCTAssertEqual(qiblaDirection.location.longitude, location.coordinate.longitude, accuracy: 0.001)
    }
    
    func testPrayerTimesToNotificationFlow() async throws {
        // Given
        let locationService = dependencyContainer.locationService as! MockLocationService
        let apiClient = dependencyContainer.apiClient as! MockAPIClient
        let notificationService = dependencyContainer.notificationService as! MockNotificationService
        
        locationService.setMockPermissionStatus(.authorizedWhenInUse)
        apiClient.setNetworkAvailable(true)
        notificationService.setMockPermissionStatus(.authorized)
        
        // When - Get prayer times and schedule notifications
        let location = try await locationService.getCurrentLocation()
        let prayerTimes = try await apiClient.getPrayerTimes(
            for: Date(),
            location: location.coordinate,
            calculationMethod: .muslimWorldLeague,
            madhab: .shafi
        )
        
        try await notificationService.schedulePrayerNotifications(for: prayerTimes)
        
        // Then - Notifications should be scheduled for all prayers
        let pendingNotifications = await notificationService.getPendingNotifications()
        let scheduledPrayers = Set(pendingNotifications.map { $0.prayer })
        
        XCTAssertEqual(scheduledPrayers.count, Prayer.allCases.count)
        
        // Verify notification times are before prayer times
        for notification in pendingNotifications {
            let prayerTime = prayerTimes.time(for: notification.prayer)
            XCTAssertLessThan(notification.scheduledTime, prayerTime)
        }
    }
    
    // MARK: - Error Recovery Tests
    
    func testErrorRecoveryFlow() async throws {
        // Given
        let locationService = dependencyContainer.locationService as! MockLocationService
        let apiClient = dependencyContainer.apiClient as! MockAPIClient
        
        locationService.setMockPermissionStatus(.authorizedWhenInUse)
        
        // When - Network error occurs
        apiClient.setNetworkAvailable(false)
        
        // Then - Should gracefully handle errors and provide fallbacks
        let location = try await locationService.getCurrentLocation()
        
        // API should fail but qibla can still be calculated locally
        let qiblaDirection = try await apiClient.getQiblaDirection(for: location.coordinate)
        XCTAssertGreaterThan(qiblaDirection.direction, 0)
        
        // When - Network recovers
        apiClient.setNetworkAvailable(true)
        
        // Then - API calls should work again
        let prayerTimes = try await apiClient.getPrayerTimes(
            for: Date(),
            location: location.coordinate,
            calculationMethod: .muslimWorldLeague,
            madhab: .shafi
        )
        XCTAssertNotNil(prayerTimes)
    }
    
    // MARK: - Performance Tests
    
    func testConcurrentServiceCalls() async throws {
        // Given
        let locationService = dependencyContainer.locationService as! MockLocationService
        let apiClient = dependencyContainer.apiClient as! MockAPIClient
        
        locationService.setMockPermissionStatus(.authorizedWhenInUse)
        apiClient.setNetworkAvailable(true)
        
        let location = try await locationService.getCurrentLocation()
        
        // When - Make concurrent API calls
        async let prayerTimesTask = apiClient.getPrayerTimes(
            for: Date(),
            location: location.coordinate,
            calculationMethod: .muslimWorldLeague,
            madhab: .shafi
        )
        
        async let qiblaDirectionTask = apiClient.getQiblaDirection(for: location.coordinate)
        async let healthCheckTask = apiClient.checkAPIHealth()
        
        // Then - All calls should complete successfully
        let (prayerTimes, qiblaDirection, isHealthy) = try await (prayerTimesTask, qiblaDirectionTask, healthCheckTask)
        
        XCTAssertNotNil(prayerTimes)
        XCTAssertNotNil(qiblaDirection)
        XCTAssertTrue(isHealthy)
    }
    
    // MARK: - Helper Methods
    
    private func createMockPrayerTimes() -> PrayerTimes {
        let calendar = Calendar.current
        let today = Date()
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: today)
        
        let fajr = calendar.date(from: DateComponents(
            year: dateComponents.year,
            month: dateComponents.month,
            day: dateComponents.day,
            hour: 5,
            minute: 30
        )) ?? today
        
        let dhuhr = calendar.date(from: DateComponents(
            year: dateComponents.year,
            month: dateComponents.month,
            day: dateComponents.day,
            hour: 12,
            minute: 30
        )) ?? today
        
        let asr = calendar.date(from: DateComponents(
            year: dateComponents.year,
            month: dateComponents.month,
            day: dateComponents.day,
            hour: 15,
            minute: 30
        )) ?? today
        
        let maghrib = calendar.date(from: DateComponents(
            year: dateComponents.year,
            month: dateComponents.month,
            day: dateComponents.day,
            hour: 18,
            minute: 30
        )) ?? today
        
        let isha = calendar.date(from: DateComponents(
            year: dateComponents.year,
            month: dateComponents.month,
            day: dateComponents.day,
            hour: 20,
            minute: 0
        )) ?? today
        
        return PrayerTimes(
            date: today,
            fajr: fajr,
            dhuhr: dhuhr,
            asr: asr,
            maghrib: maghrib,
            isha: isha,
            calculationMethod: "MuslimWorldLeague",
            location: LocationCoordinate(latitude: 40.7128, longitude: -74.0060)
        )
    }
}
