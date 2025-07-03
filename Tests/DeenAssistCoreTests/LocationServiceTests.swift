import XCTest
import Combine
@testable import DeenAssistCore

final class LocationServiceTests: XCTestCase {
    var mockLocationService: MockLocationService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockLocationService = MockLocationService()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        mockLocationService = nil
        super.tearDown()
    }
    
    // MARK: - Permission Tests
    
    func testRequestLocationPermission_Success() async {
        // Given
        mockLocationService.setMockPermissionStatus(.authorizedWhenInUse)
        
        // When
        let status = await mockLocationService.requestLocationPermission()
        
        // Then
        XCTAssertEqual(status, .authorizedWhenInUse)
        XCTAssertEqual(mockLocationService.permissionStatus, .authorizedWhenInUse)
    }
    
    func testRequestLocationPermission_Denied() async {
        // Given
        mockLocationService.setMockPermissionStatus(.denied)
        
        // When
        let status = await mockLocationService.requestLocationPermission()
        
        // Then
        XCTAssertEqual(status, .denied)
        XCTAssertEqual(mockLocationService.permissionStatus, .denied)
    }
    
    // MARK: - Location Retrieval Tests
    
    func testGetCurrentLocation_Success() async throws {
        // Given
        mockLocationService.setMockPermissionStatus(.authorizedWhenInUse)
        let expectedLocation = LocationInfo(
            coordinate: LocationCoordinate(latitude: 40.7128, longitude: -74.0060),
            accuracy: 10.0,
            city: "New York",
            country: "United States"
        )
        mockLocationService.addMockLocation(expectedLocation)
        
        // When
        let location = try await mockLocationService.getCurrentLocation()
        
        // Then
        XCTAssertEqual(location.coordinate.latitude, expectedLocation.coordinate.latitude, accuracy: 0.001)
        XCTAssertEqual(location.coordinate.longitude, expectedLocation.coordinate.longitude, accuracy: 0.001)
        XCTAssertEqual(location.city, expectedLocation.city)
        XCTAssertEqual(location.country, expectedLocation.country)
    }
    
    func testGetCurrentLocation_PermissionDenied() async {
        // Given
        mockLocationService.setMockPermissionStatus(.denied)
        
        // When/Then
        do {
            _ = try await mockLocationService.getCurrentLocation()
            XCTFail("Expected LocationError.permissionDenied")
        } catch LocationError.permissionDenied {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testGetCurrentLocation_LocationUnavailable() async {
        // Given
        mockLocationService.setMockPermissionStatus(.authorizedWhenInUse)
        mockLocationService.simulateLocationError(.locationUnavailable)
        
        // When/Then
        do {
            _ = try await mockLocationService.getCurrentLocation()
            XCTFail("Expected LocationError.locationUnavailable")
        } catch LocationError.locationUnavailable {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - City Search Tests
    
    func testSearchCity_Success() async throws {
        // Given
        mockLocationService.setMockPermissionStatus(.authorizedWhenInUse)
        let cityName = "New York"
        
        // When
        let results = try await mockLocationService.searchCity(cityName)
        
        // Then
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.contains { $0.city?.contains("New York") == true })
    }
    
    func testSearchCity_NoResults() async throws {
        // Given
        mockLocationService.setMockPermissionStatus(.authorizedWhenInUse)
        let cityName = "NonexistentCity12345"
        
        // When
        let results = try await mockLocationService.searchCity(cityName)
        
        // Then
        XCTAssertTrue(results.isEmpty)
    }
    
    func testSearchCity_NetworkError() async {
        // Given
        mockLocationService.setMockPermissionStatus(.authorizedWhenInUse)
        mockLocationService.simulateLocationError(.networkError)
        
        // When/Then
        do {
            _ = try await mockLocationService.searchCity("Test City")
            XCTFail("Expected LocationError.networkError")
        } catch LocationError.networkError {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Location Updates Tests
    
    func testStartLocationUpdates() {
        // Given
        mockLocationService.setMockPermissionStatus(.authorizedWhenInUse)
        
        // When
        mockLocationService.startLocationUpdates()
        
        // Then
        XCTAssertTrue(mockLocationService.isLocationActive)
    }
    
    func testStopLocationUpdates() {
        // Given
        mockLocationService.setMockPermissionStatus(.authorizedWhenInUse)
        mockLocationService.startLocationUpdates()
        
        // When
        mockLocationService.stopLocationUpdates()
        
        // Then
        XCTAssertFalse(mockLocationService.isLocationActive)
    }
    
    // MARK: - Cache Tests
    
    func testLocationCaching() async throws {
        // Given
        mockLocationService.setMockPermissionStatus(.authorizedWhenInUse)
        let expectedLocation = LocationInfo(
            coordinate: LocationCoordinate(latitude: 25.2048, longitude: 55.2708),
            accuracy: 5.0,
            city: "Dubai",
            country: "UAE"
        )
        mockLocationService.addMockLocation(expectedLocation)
        
        // When
        let location = try await mockLocationService.getCurrentLocation()
        let cachedLocation = mockLocationService.getCachedLocation()
        
        // Then
        XCTAssertNotNil(cachedLocation)
        XCTAssertEqual(location.coordinate.latitude, cachedLocation?.coordinate.latitude, accuracy: 0.001)
        XCTAssertEqual(location.coordinate.longitude, cachedLocation?.coordinate.longitude, accuracy: 0.001)
    }
    
    func testClearLocationCache() {
        // Given
        let location = LocationInfo(
            coordinate: LocationCoordinate(latitude: 40.7128, longitude: -74.0060),
            accuracy: 10.0
        )
        mockLocationService.addMockLocation(location)
        
        // When
        mockLocationService.clearLocationCache()
        
        // Then
        XCTAssertNil(mockLocationService.getCachedLocation())
    }
    
    // MARK: - Publisher Tests
    
    func testLocationPublisher() async throws {
        // Given
        mockLocationService.setMockPermissionStatus(.authorizedWhenInUse)
        let expectation = XCTestExpectation(description: "Location published")
        
        mockLocationService.locationPublisher
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { location in
                    XCTAssertNotNil(location)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        // When
        _ = try await mockLocationService.getCurrentLocation()
        
        // Then
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    func testPermissionPublisher() async {
        // Given
        let expectation = XCTestExpectation(description: "Permission status published")
        
        mockLocationService.permissionPublisher
            .sink { status in
                XCTAssertEqual(status, .authorizedWhenInUse)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When
        mockLocationService.setMockPermissionStatus(.authorizedWhenInUse)
        
        // Then
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    // MARK: - Utility Tests
    
    func testIsLocationServicesAvailable() {
        // When/Then
        XCTAssertTrue(mockLocationService.isLocationServicesAvailable())
    }
    
    func testBestAvailableLocation() async throws {
        // Given
        mockLocationService.setMockPermissionStatus(.authorizedWhenInUse)
        let location = try await mockLocationService.getCurrentLocation()
        
        // When
        let bestLocation = mockLocationService.getBestAvailableLocation()
        
        // Then
        XCTAssertNotNil(bestLocation)
        XCTAssertEqual(bestLocation?.coordinate.latitude, location.coordinate.latitude, accuracy: 0.001)
    }
}
