import XCTest
import Combine
@testable import DeenAssistCore

final class APIClientTests: XCTestCase {
    var mockAPIClient: MockAPIClient!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockAPIClient = MockAPIClient()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        mockAPIClient = nil
        super.tearDown()
    }
    
    // MARK: - Prayer Times Tests
    
    func testGetPrayerTimes_Success() async throws {
        // Given
        let location = LocationCoordinate(latitude: 40.7128, longitude: -74.0060)
        let date = Date()
        let calculationMethod = CalculationMethod.muslimWorldLeague
        let madhab = Madhab.shafi
        
        mockAPIClient.setNetworkAvailable(true)
        
        // When
        let prayerTimes = try await mockAPIClient.getPrayerTimes(
            for: date,
            location: location,
            calculationMethod: calculationMethod,
            madhab: madhab
        )
        
        // Then
        XCTAssertEqual(prayerTimes.location.latitude, location.latitude, accuracy: 0.001)
        XCTAssertEqual(prayerTimes.location.longitude, location.longitude, accuracy: 0.001)
        XCTAssertEqual(prayerTimes.calculationMethod, calculationMethod.rawValue)
        
        // Verify prayer times are in correct order
        XCTAssertLessThan(prayerTimes.fajr, prayerTimes.dhuhr)
        XCTAssertLessThan(prayerTimes.dhuhr, prayerTimes.asr)
        XCTAssertLessThan(prayerTimes.asr, prayerTimes.maghrib)
        XCTAssertLessThan(prayerTimes.maghrib, prayerTimes.isha)
    }
    
    func testGetPrayerTimes_NetworkError() async {
        // Given
        let location = LocationCoordinate(latitude: 40.7128, longitude: -74.0060)
        let date = Date()
        
        mockAPIClient.setNetworkAvailable(false)
        
        // When/Then
        do {
            _ = try await mockAPIClient.getPrayerTimes(
                for: date,
                location: location,
                calculationMethod: .muslimWorldLeague,
                madhab: .shafi
            )
            XCTFail("Expected APIError.networkError")
        } catch APIError.networkError {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testGetPrayerTimes_RateLimited() async {
        // Given
        let location = LocationCoordinate(latitude: 40.7128, longitude: -74.0060)
        let date = Date()
        
        mockAPIClient.setNetworkAvailable(true)
        mockAPIClient.setRateLimited(true)
        
        // When/Then
        do {
            _ = try await mockAPIClient.getPrayerTimes(
                for: date,
                location: location,
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
    
    func testGetPrayerTimes_Caching() async throws {
        // Given
        let location = LocationCoordinate(latitude: 40.7128, longitude: -74.0060)
        let date = Date()
        
        mockAPIClient.setNetworkAvailable(true)
        
        // When - First request
        let prayerTimes1 = try await mockAPIClient.getPrayerTimes(
            for: date,
            location: location,
            calculationMethod: .muslimWorldLeague,
            madhab: .shafi
        )
        
        // When - Second request (should use cache)
        let prayerTimes2 = try await mockAPIClient.getPrayerTimes(
            for: date,
            location: location,
            calculationMethod: .muslimWorldLeague,
            madhab: .shafi
        )
        
        // Then
        XCTAssertEqual(prayerTimes1.fajr, prayerTimes2.fajr)
        XCTAssertEqual(prayerTimes1.dhuhr, prayerTimes2.dhuhr)
        XCTAssertEqual(prayerTimes1.asr, prayerTimes2.asr)
        XCTAssertEqual(prayerTimes1.maghrib, prayerTimes2.maghrib)
        XCTAssertEqual(prayerTimes1.isha, prayerTimes2.isha)
    }
    
    // MARK: - Qibla Direction Tests
    
    func testGetQiblaDirection_Success() async throws {
        // Given
        let location = LocationCoordinate(latitude: 40.7128, longitude: -74.0060) // New York
        
        mockAPIClient.setNetworkAvailable(true)
        
        // When
        let qiblaDirection = try await mockAPIClient.getQiblaDirection(for: location)
        
        // Then
        XCTAssertEqual(qiblaDirection.location.latitude, location.latitude, accuracy: 0.001)
        XCTAssertEqual(qiblaDirection.location.longitude, location.longitude, accuracy: 0.001)
        XCTAssertGreaterThan(qiblaDirection.direction, 0)
        XCTAssertLessThan(qiblaDirection.direction, 360)
        XCTAssertGreaterThan(qiblaDirection.distance, 0)
    }
    
    func testGetQiblaDirection_NetworkError() async throws {
        // Given
        let location = LocationCoordinate(latitude: 40.7128, longitude: -74.0060)
        
        mockAPIClient.setNetworkAvailable(false)
        
        // When - Should fallback to local calculation
        let qiblaDirection = try await mockAPIClient.getQiblaDirection(for: location)
        
        // Then - Should still return a valid direction (local calculation)
        XCTAssertEqual(qiblaDirection.location.latitude, location.latitude, accuracy: 0.001)
        XCTAssertEqual(qiblaDirection.location.longitude, location.longitude, accuracy: 0.001)
        XCTAssertGreaterThan(qiblaDirection.direction, 0)
        XCTAssertLessThan(qiblaDirection.direction, 360)
    }
    
    func testGetQiblaDirection_Caching() async throws {
        // Given
        let location = LocationCoordinate(latitude: 25.2048, longitude: 55.2708) // Dubai
        
        mockAPIClient.setNetworkAvailable(true)
        
        // When - First request
        let qiblaDirection1 = try await mockAPIClient.getQiblaDirection(for: location)
        
        // When - Second request (should use cache)
        let qiblaDirection2 = try await mockAPIClient.getQiblaDirection(for: location)
        
        // Then
        XCTAssertEqual(qiblaDirection1.direction, qiblaDirection2.direction, accuracy: 0.001)
        XCTAssertEqual(qiblaDirection1.distance, qiblaDirection2.distance, accuracy: 0.001)
    }
    
    // MARK: - API Health Tests
    
    func testCheckAPIHealth_Success() async throws {
        // Given
        mockAPIClient.setNetworkAvailable(true)
        
        // When
        let isHealthy = try await mockAPIClient.checkAPIHealth()
        
        // Then
        XCTAssertTrue(isHealthy)
    }
    
    func testCheckAPIHealth_NetworkUnavailable() async throws {
        // Given
        mockAPIClient.setNetworkAvailable(false)
        
        // When
        let isHealthy = try await mockAPIClient.checkAPIHealth()
        
        // Then
        XCTAssertFalse(isHealthy)
    }
    
    func testCheckAPIHealth_Error() async {
        // Given
        mockAPIClient.setNetworkAvailable(true)
        mockAPIClient.simulateNetworkError(.serverError(500, "Internal Server Error"))
        
        // When/Then
        do {
            _ = try await mockAPIClient.checkAPIHealth()
            XCTFail("Expected APIError.serverError")
        } catch APIError.serverError {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Rate Limiting Tests
    
    func testGetRateLimitStatus() {
        // When
        let status = mockAPIClient.getRateLimitStatus()
        
        // Then
        XCTAssertGreaterThanOrEqual(status.requestsRemaining, 0)
        XCTAssertGreaterThan(status.resetTime, Date())
    }
    
    func testRateLimitTracking() async throws {
        // Given
        mockAPIClient.setNetworkAvailable(true)
        let location = LocationCoordinate(latitude: 40.7128, longitude: -74.0060)
        
        let initialStatus = mockAPIClient.getRateLimitStatus()
        let initialRemaining = initialStatus.requestsRemaining
        
        // When
        _ = try await mockAPIClient.getPrayerTimes(
            for: Date(),
            location: location,
            calculationMethod: .muslimWorldLeague,
            madhab: .shafi
        )
        
        let afterStatus = mockAPIClient.getRateLimitStatus()
        
        // Then
        XCTAssertLessThan(afterStatus.requestsRemaining, initialRemaining)
    }
    
    // MARK: - Network Status Tests
    
    func testNetworkStatusPublisher() async {
        // Given
        let expectation = XCTestExpectation(description: "Network status published")
        
        mockAPIClient.networkStatusPublisher
            .sink { isAvailable in
                XCTAssertFalse(isAvailable)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When
        mockAPIClient.setNetworkAvailable(false)
        
        // Then
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    // MARK: - Mock Configuration Tests
    
    func testMockConfiguration() {
        // Given
        let customError = APIError.timeout
        
        // When
        mockAPIClient.simulateNetworkError(customError)
        
        // Then
        XCTAssertTrue(mockAPIClient.shouldFailRequests)
    }
    
    func testClearMockCache() {
        // Given
        mockAPIClient.clearMockCache()
        
        // When/Then - Should not crash and should work normally
        XCTAssertTrue(mockAPIClient.isNetworkAvailable)
    }
    
    // MARK: - Calculation Method Tests
    
    func testDifferentCalculationMethods() async throws {
        // Given
        let location = LocationCoordinate(latitude: 21.4225, longitude: 39.8262) // Mecca
        let date = Date()
        
        mockAPIClient.setNetworkAvailable(true)
        
        // When/Then - Test different calculation methods
        for method in CalculationMethod.allCases {
            let prayerTimes = try await mockAPIClient.getPrayerTimes(
                for: date,
                location: location,
                calculationMethod: method,
                madhab: .shafi
            )
            
            XCTAssertEqual(prayerTimes.calculationMethod, method.rawValue)
            XCTAssertLessThan(prayerTimes.fajr, prayerTimes.dhuhr)
        }
    }
    
    func testDifferentMadhabs() async throws {
        // Given
        let location = LocationCoordinate(latitude: 40.7128, longitude: -74.0060)
        let date = Date()
        
        mockAPIClient.setNetworkAvailable(true)
        
        // When
        let shafiTimes = try await mockAPIClient.getPrayerTimes(
            for: date,
            location: location,
            calculationMethod: .muslimWorldLeague,
            madhab: .shafi
        )
        
        let hanafiTimes = try await mockAPIClient.getPrayerTimes(
            for: date,
            location: location,
            calculationMethod: .muslimWorldLeague,
            madhab: .hanafi
        )
        
        // Then - Hanafi Asr should be later than Shafi Asr
        XCTAssertLessThanOrEqual(shafiTimes.asr, hanafiTimes.asr)
    }
}
