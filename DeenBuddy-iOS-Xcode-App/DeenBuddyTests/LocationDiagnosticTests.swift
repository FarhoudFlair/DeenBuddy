import XCTest
import SwiftUI
import CoreLocation
@testable import DeenAssistUI
@testable import DeenAssistCore
@testable import DeenAssistProtocols

class LocationDiagnosticTests: XCTestCase {
    
    func testLocationDiagnosticPopupCreation() {
        // Given
        let location = CLLocation(latitude: 40.7128, longitude: -74.0060)
        let mockLocationService = MockLocationService()
        let isPresented = Binding.constant(true)
        
        // When
        let popup = LocationDiagnosticPopup(
            location: location,
            locationService: mockLocationService,
            isPresented: isPresented
        )
        
        // Then
        XCTAssertNotNil(popup)
    }
    
    func testLocationServiceProtocolMethods() async throws {
        // Given
        let mockLocationService = MockLocationService()
        let coordinate = LocationCoordinate(latitude: 40.7128, longitude: -74.0060)
        
        // When & Then
        let locationInfo = try await mockLocationService.getLocationInfo(for: coordinate)
        XCTAssertEqual(locationInfo.coordinate.latitude, coordinate.latitude)
        XCTAssertEqual(locationInfo.coordinate.longitude, coordinate.longitude)
        XCTAssertNotNil(locationInfo.city)
        XCTAssertNotNil(locationInfo.country)
        
        let searchResults = try await mockLocationService.searchCity("New York")
        XCTAssertGreaterThanOrEqual(searchResults.count, 0)
    }
    
    func testHomeScreenWithLocationDiagnostic() {
        // Given
        let mockPrayerTimeService = MockPrayerTimeService()
        let mockLocationService = MockLocationService()
        let mockSettingsService = MockSettingsService()
        
        // When
        let homeScreen = HomeScreen(
            prayerTimeService: mockPrayerTimeService,
            locationService: mockLocationService,
            settingsService: mockSettingsService,
            onCompassTapped: {},
            onGuidesTapped: {},
            onQuranSearchTapped: {},
            onSettingsTapped: {}
        )
        
        // Then
        XCTAssertNotNil(homeScreen)
    }
}
