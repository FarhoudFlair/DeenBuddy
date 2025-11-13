import XCTest
import CoreLocation
@testable import DeenBuddy

/// Comprehensive tests for DefaultPrayerConfigurationProvider
/// Tests region detection and default prayer configuration assignment based on geography
@MainActor
final class DefaultPrayerConfigurationProviderTests: XCTestCase {

    private var provider: DefaultPrayerConfigurationProvider!

    override func setUp() async throws {
        try await super.setUp()
        provider = DefaultPrayerConfigurationProvider()
    }

    override func tearDown() async throws {
        provider = nil
        try await super.tearDown()
    }

    // MARK: - Region Detection from Country Codes

    func testNorthAmericaRegionDetectionFromCountryCode() throws {
        // Test United States
        let usConfig = provider.configuration(
            coordinate: nil,
            countryName: "United States"
        )
        XCTAssertEqual(usConfig.calculationMethod, .northAmerica,
                      "United States should use North America calculation method")
        XCTAssertEqual(usConfig.madhab, .hanafi,
                      "North America should default to Hanafi madhab (large South Asian diaspora)")

        // Test Canada
        let caConfig = provider.configuration(
            coordinate: nil,
            countryName: "Canada"
        )
        XCTAssertEqual(caConfig.calculationMethod, .northAmerica)
        XCTAssertEqual(caConfig.madhab, .hanafi)

        // Test Mexico
        let mxConfig = provider.configuration(
            coordinate: nil,
            countryName: "Mexico"
        )
        XCTAssertEqual(mxConfig.calculationMethod, .northAmerica)
        XCTAssertEqual(mxConfig.madhab, .hanafi)

        print("✅ North America region detection from country codes passed")
    }

    func testSouthAsiaRegionDetectionFromCountryCode() throws {
        // Test Pakistan
        let pkConfig = provider.configuration(
            coordinate: nil,
            countryName: "Pakistan"
        )
        XCTAssertEqual(pkConfig.calculationMethod, .karachi,
                      "Pakistan should use Karachi calculation method")
        XCTAssertEqual(pkConfig.madhab, .hanafi,
                      "South Asia should default to Hanafi madhab")

        // Test India
        let inConfig = provider.configuration(
            coordinate: nil,
            countryName: "India"
        )
        XCTAssertEqual(inConfig.calculationMethod, .karachi)
        XCTAssertEqual(inConfig.madhab, .hanafi)

        // Test Bangladesh
        let bdConfig = provider.configuration(
            coordinate: nil,
            countryName: "Bangladesh"
        )
        XCTAssertEqual(bdConfig.calculationMethod, .karachi)
        XCTAssertEqual(bdConfig.madhab, .hanafi)

        print("✅ South Asia region detection from country codes passed")
    }

    func testNorthAfricaRegionDetectionFromCountryCode() throws {
        // Test Egypt
        let egConfig = provider.configuration(
            coordinate: nil,
            countryName: "Egypt"
        )
        XCTAssertEqual(egConfig.calculationMethod, .egyptian,
                      "Egypt should use Egyptian calculation method")
        XCTAssertEqual(egConfig.madhab, .shafi,
                      "North Africa should default to Shafi madhab")

        // Test Morocco
        let maConfig = provider.configuration(
            coordinate: nil,
            countryName: "Morocco"
        )
        XCTAssertEqual(maConfig.calculationMethod, .egyptian)
        XCTAssertEqual(maConfig.madhab, .shafi)

        print("✅ North Africa region detection from country codes passed")
    }

    func testGulfStatesRegionDetectionFromCountryCode() throws {
        // Test Saudi Arabia
        let saConfig = provider.configuration(
            coordinate: nil,
            countryName: "Saudi Arabia"
        )
        XCTAssertEqual(saConfig.calculationMethod, .ummAlQura,
                      "Saudi Arabia should use Umm Al-Qura calculation method")
        XCTAssertEqual(saConfig.madhab, .shafi,
                      "Gulf States should default to Shafi madhab")

        // Test UAE
        let aeConfig = provider.configuration(
            coordinate: nil,
            countryName: "United Arab Emirates"
        )
        XCTAssertEqual(aeConfig.calculationMethod, .ummAlQura)
        XCTAssertEqual(aeConfig.madhab, .shafi)

        // Test Kuwait
        let kwConfig = provider.configuration(
            coordinate: nil,
            countryName: "Kuwait"
        )
        XCTAssertEqual(kwConfig.calculationMethod, .ummAlQura)
        XCTAssertEqual(kwConfig.madhab, .shafi)

        print("✅ Gulf States region detection from country codes passed")
    }

    func testSoutheastAsiaRegionDetectionFromCountryCode() throws {
        // Test Indonesia
        let idConfig = provider.configuration(
            coordinate: nil,
            countryName: "Indonesia"
        )
        XCTAssertEqual(idConfig.calculationMethod, .singapore,
                      "Indonesia should use Singapore calculation method")
        XCTAssertEqual(idConfig.madhab, .shafi,
                      "Southeast Asia should default to Shafi madhab")

        // Test Malaysia
        let myConfig = provider.configuration(
            coordinate: nil,
            countryName: "Malaysia"
        )
        XCTAssertEqual(myConfig.calculationMethod, .singapore)
        XCTAssertEqual(myConfig.madhab, .shafi)

        // Test Singapore
        let sgConfig = provider.configuration(
            coordinate: nil,
            countryName: "Singapore"
        )
        XCTAssertEqual(sgConfig.calculationMethod, .singapore)
        XCTAssertEqual(sgConfig.madhab, .shafi)

        print("✅ Southeast Asia region detection from country codes passed")
    }

    func testEastAfricaRegionDetectionFromCountryCode() throws {
        // Test Somalia
        let soConfig = provider.configuration(
            coordinate: nil,
            countryName: "Somalia"
        )
        XCTAssertEqual(soConfig.calculationMethod, .muslimWorldLeague,
                      "East Africa should use Muslim World League calculation method")
        XCTAssertEqual(soConfig.madhab, .shafi,
                      "East Africa should default to Shafi madhab")

        // Test Kenya
        let keConfig = provider.configuration(
            coordinate: nil,
            countryName: "Kenya"
        )
        XCTAssertEqual(keConfig.calculationMethod, .muslimWorldLeague)
        XCTAssertEqual(keConfig.madhab, .shafi)

        print("✅ East Africa region detection from country codes passed")
    }

    func testMiddleEastRegionDetectionFromCountryCode() throws {
        // Test Jordan
        let joConfig = provider.configuration(
            coordinate: nil,
            countryName: "Jordan"
        )
        XCTAssertEqual(joConfig.calculationMethod, .muslimWorldLeague,
                      "Middle East should use Muslim World League calculation method")
        XCTAssertEqual(joConfig.madhab, .shafi,
                      "Middle East should default to Shafi madhab")

        // Test Lebanon
        let lbConfig = provider.configuration(
            coordinate: nil,
            countryName: "Lebanon"
        )
        XCTAssertEqual(lbConfig.calculationMethod, .muslimWorldLeague)
        XCTAssertEqual(lbConfig.madhab, .shafi)

        print("✅ Middle East region detection from country codes passed")
    }

    func testCentralAsiaRegionDetectionFromCountryCode() throws {
        // Test Turkey
        let trConfig = provider.configuration(
            coordinate: nil,
            countryName: "Turkey"
        )
        XCTAssertEqual(trConfig.calculationMethod, .muslimWorldLeague,
                      "Central Asia should use Muslim World League calculation method")
        XCTAssertEqual(trConfig.madhab, .hanafi,
                      "Central Asia should default to Hanafi madhab")

        // Test Kazakhstan
        let kzConfig = provider.configuration(
            coordinate: nil,
            countryName: "Kazakhstan"
        )
        XCTAssertEqual(kzConfig.calculationMethod, .muslimWorldLeague)
        XCTAssertEqual(kzConfig.madhab, .hanafi)

        print("✅ Central Asia region detection from country codes passed")
    }

    func testEuropeRegionDetectionFromCountryCode() throws {
        // Test United Kingdom
        let gbConfig = provider.configuration(
            coordinate: nil,
            countryName: "United Kingdom"
        )
        XCTAssertEqual(gbConfig.calculationMethod, .muslimWorldLeague,
                      "Europe should use Muslim World League calculation method")
        XCTAssertEqual(gbConfig.madhab, .hanafi,
                      "Europe should default to Hanafi madhab (large Turkish and South Asian communities)")

        // Test France
        let frConfig = provider.configuration(
            coordinate: nil,
            countryName: "France"
        )
        XCTAssertEqual(frConfig.calculationMethod, .muslimWorldLeague)
        XCTAssertEqual(frConfig.madhab, .hanafi)

        // Test Germany
        let deConfig = provider.configuration(
            coordinate: nil,
            countryName: "Germany"
        )
        XCTAssertEqual(deConfig.calculationMethod, .muslimWorldLeague)
        XCTAssertEqual(deConfig.madhab, .hanafi)

        print("✅ Europe region detection from country codes passed")
    }

    // MARK: - Region Detection from Coordinates

    func testNorthAmericaRegionDetectionFromCoordinates() throws {
        // New York, USA
        let nyConfig = provider.configuration(
            coordinate: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060),
            countryName: nil
        )
        XCTAssertEqual(nyConfig.calculationMethod, .northAmerica)
        XCTAssertEqual(nyConfig.madhab, .hanafi)

        // Toronto, Canada
        let toConfig = provider.configuration(
            coordinate: CLLocationCoordinate2D(latitude: 43.6532, longitude: -79.3832),
            countryName: nil
        )
        XCTAssertEqual(toConfig.calculationMethod, .northAmerica)
        XCTAssertEqual(toConfig.madhab, .hanafi)

        // Mexico City, Mexico
        let mxConfig = provider.configuration(
            coordinate: CLLocationCoordinate2D(latitude: 19.4326, longitude: -99.1332),
            countryName: nil
        )
        XCTAssertEqual(mxConfig.calculationMethod, .northAmerica)
        XCTAssertEqual(mxConfig.madhab, .hanafi)

        print("✅ North America coordinate-based detection passed")
    }

    func testSouthAsiaRegionDetectionFromCoordinates() throws {
        // Karachi, Pakistan
        let karachiConfig = provider.configuration(
            coordinate: CLLocationCoordinate2D(latitude: 24.8607, longitude: 67.0011),
            countryName: nil
        )
        XCTAssertEqual(karachiConfig.calculationMethod, .karachi)
        XCTAssertEqual(karachiConfig.madhab, .hanafi)

        // New Delhi, India
        let delhiConfig = provider.configuration(
            coordinate: CLLocationCoordinate2D(latitude: 28.6139, longitude: 77.2090),
            countryName: nil
        )
        XCTAssertEqual(delhiConfig.calculationMethod, .karachi)
        XCTAssertEqual(delhiConfig.madhab, .hanafi)

        // Dhaka, Bangladesh
        let dhakaConfig = provider.configuration(
            coordinate: CLLocationCoordinate2D(latitude: 23.8103, longitude: 90.4125),
            countryName: nil
        )
        XCTAssertEqual(dhakaConfig.calculationMethod, .karachi)
        XCTAssertEqual(dhakaConfig.madhab, .hanafi)

        print("✅ South Asia coordinate-based detection passed")
    }

    func testNorthAfricaRegionDetectionFromCoordinates() throws {
        // Cairo, Egypt
        let cairoConfig = provider.configuration(
            coordinate: CLLocationCoordinate2D(latitude: 30.0444, longitude: 31.2357),
            countryName: nil
        )
        XCTAssertEqual(cairoConfig.calculationMethod, .egyptian)
        XCTAssertEqual(cairoConfig.madhab, .shafi)

        // Casablanca, Morocco
        let casaConfig = provider.configuration(
            coordinate: CLLocationCoordinate2D(latitude: 33.5731, longitude: -7.5898),
            countryName: nil
        )
        XCTAssertEqual(casaConfig.calculationMethod, .egyptian)
        XCTAssertEqual(casaConfig.madhab, .shafi)

        print("✅ North Africa coordinate-based detection passed")
    }

    func testGulfStatesRegionDetectionFromCoordinates() throws {
        // Mecca, Saudi Arabia
        let meccaConfig = provider.configuration(
            coordinate: CLLocationCoordinate2D(latitude: 21.4225, longitude: 39.8262),
            countryName: nil
        )
        XCTAssertEqual(meccaConfig.calculationMethod, .ummAlQura)
        XCTAssertEqual(meccaConfig.madhab, .shafi)

        // Dubai, UAE
        let dubaiConfig = provider.configuration(
            coordinate: CLLocationCoordinate2D(latitude: 25.2048, longitude: 55.2708),
            countryName: nil
        )
        XCTAssertEqual(dubaiConfig.calculationMethod, .ummAlQura)
        XCTAssertEqual(dubaiConfig.madhab, .shafi)

        print("✅ Gulf States coordinate-based detection passed")
    }

    func testSoutheastAsiaRegionDetectionFromCoordinates() throws {
        // Jakarta, Indonesia
        let jakartaConfig = provider.configuration(
            coordinate: CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456),
            countryName: nil
        )
        XCTAssertEqual(jakartaConfig.calculationMethod, .singapore)
        XCTAssertEqual(jakartaConfig.madhab, .shafi)

        // Kuala Lumpur, Malaysia
        let klConfig = provider.configuration(
            coordinate: CLLocationCoordinate2D(latitude: 3.1390, longitude: 101.6869),
            countryName: nil
        )
        XCTAssertEqual(klConfig.calculationMethod, .singapore)
        XCTAssertEqual(klConfig.madhab, .shafi)

        print("✅ Southeast Asia coordinate-based detection passed")
    }

    func testEastAfricaRegionDetectionFromCoordinates() throws {
        // Nairobi, Kenya
        let nairobiConfig = provider.configuration(
            coordinate: CLLocationCoordinate2D(latitude: -1.2864, longitude: 36.8172),
            countryName: nil
        )
        XCTAssertEqual(nairobiConfig.calculationMethod, .muslimWorldLeague)
        XCTAssertEqual(nairobiConfig.madhab, .shafi)

        // Dar es Salaam, Tanzania
        let darConfig = provider.configuration(
            coordinate: CLLocationCoordinate2D(latitude: -6.7924, longitude: 39.2083),
            countryName: nil
        )
        XCTAssertEqual(darConfig.calculationMethod, .muslimWorldLeague)
        XCTAssertEqual(darConfig.madhab, .shafi)

        print("✅ East Africa coordinate-based detection passed")
    }

    func testMiddleEastRegionDetectionFromCoordinates() throws {
        // Amman, Jordan
        let ammanConfig = provider.configuration(
            coordinate: CLLocationCoordinate2D(latitude: 31.9454, longitude: 35.9284),
            countryName: nil
        )
        XCTAssertEqual(ammanConfig.calculationMethod, .muslimWorldLeague)
        XCTAssertEqual(ammanConfig.madhab, .shafi)

        // Beirut, Lebanon
        let beirutConfig = provider.configuration(
            coordinate: CLLocationCoordinate2D(latitude: 33.8886, longitude: 35.4955),
            countryName: nil
        )
        XCTAssertEqual(beirutConfig.calculationMethod, .muslimWorldLeague)
        XCTAssertEqual(beirutConfig.madhab, .shafi)

        print("✅ Middle East coordinate-based detection passed")
    }

    func testCentralAsiaRegionDetectionFromCoordinates() throws {
        // Istanbul, Turkey
        let istanbulConfig = provider.configuration(
            coordinate: CLLocationCoordinate2D(latitude: 41.0082, longitude: 28.9784),
            countryName: nil
        )
        XCTAssertEqual(istanbulConfig.calculationMethod, .muslimWorldLeague)
        XCTAssertEqual(istanbulConfig.madhab, .hanafi)

        // Tashkent, Uzbekistan
        let tashkentConfig = provider.configuration(
            coordinate: CLLocationCoordinate2D(latitude: 41.2995, longitude: 69.2401),
            countryName: nil
        )
        XCTAssertEqual(tashkentConfig.calculationMethod, .muslimWorldLeague)
        XCTAssertEqual(tashkentConfig.madhab, .hanafi)

        print("✅ Central Asia coordinate-based detection passed")
    }

    func testEuropeRegionDetectionFromCoordinates() throws {
        // London, UK
        let londonConfig = provider.configuration(
            coordinate: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
            countryName: nil
        )
        XCTAssertEqual(londonConfig.calculationMethod, .muslimWorldLeague)
        XCTAssertEqual(londonConfig.madhab, .hanafi)

        // Paris, France
        let parisConfig = provider.configuration(
            coordinate: CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522),
            countryName: nil
        )
        XCTAssertEqual(parisConfig.calculationMethod, .muslimWorldLeague)
        XCTAssertEqual(parisConfig.madhab, .hanafi)

        print("✅ Europe coordinate-based detection passed")
    }

    // MARK: - Edge Cases and Fallbacks

    func testFallbackToOtherRegionWhenNoMatchFound() throws {
        // Antarctica coordinates (no specific region)
        let antarcticaConfig = provider.configuration(
            coordinate: CLLocationCoordinate2D(latitude: -75.0, longitude: 0.0),
            countryName: nil
        )
        XCTAssertEqual(antarcticaConfig.calculationMethod, .muslimWorldLeague,
                      "Unknown regions should default to Muslim World League")
        XCTAssertEqual(antarcticaConfig.madhab, .shafi,
                      "Unknown regions should default to Shafi madhab (most common globally)")

        print("✅ Fallback to 'other' region passed")
    }

    func testNilCoordinatesAndNilCountryName() throws {
        // No information provided
        let config = provider.configuration(
            coordinate: nil,
            countryName: nil
        )
        XCTAssertEqual(config.calculationMethod, .muslimWorldLeague,
                      "No information should default to Muslim World League")
        XCTAssertEqual(config.madhab, .shafi,
                      "No information should default to Shafi madhab")

        print("✅ Nil coordinates and country name fallback passed")
    }

    func testInvalidCountryName() throws {
        // Invalid country name
        let config = provider.configuration(
            coordinate: nil,
            countryName: "NonExistentCountry123"
        )
        XCTAssertEqual(config.calculationMethod, .muslimWorldLeague)
        XCTAssertEqual(config.madhab, .shafi)

        print("✅ Invalid country name fallback passed")
    }

    func testCountryCodeTakesPrecedenceOverCoordinates() throws {
        // Provide Pakistan country name with US coordinates
        // Country code should take precedence
        let config = provider.configuration(
            coordinate: CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060), // New York coordinates
            countryName: "Pakistan"
        )
        XCTAssertEqual(config.calculationMethod, .karachi,
                      "Country code should take precedence over coordinates")
        XCTAssertEqual(config.madhab, .hanafi)

        print("✅ Country code precedence over coordinates passed")
    }

    // MARK: - Comprehensive Region Coverage Test

    func testAllRegionsHaveValidConfiguration() throws {
        let testCases: [(String, CLLocationCoordinate2D?, String?, CalculationMethod, Madhab)] = [
            ("North America", CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060), nil, .northAmerica, .hanafi),
            ("South Asia", CLLocationCoordinate2D(latitude: 24.8607, longitude: 67.0011), nil, .karachi, .hanafi),
            ("North Africa", CLLocationCoordinate2D(latitude: 30.0444, longitude: 31.2357), nil, .egyptian, .shafi),
            ("Gulf States", CLLocationCoordinate2D(latitude: 21.4225, longitude: 39.8262), nil, .ummAlQura, .shafi),
            ("Southeast Asia", CLLocationCoordinate2D(latitude: -6.2088, longitude: 106.8456), nil, .singapore, .shafi),
            ("East Africa", CLLocationCoordinate2D(latitude: -1.2864, longitude: 36.8172), nil, .muslimWorldLeague, .shafi),
            ("Middle East", CLLocationCoordinate2D(latitude: 31.9454, longitude: 35.9284), nil, .muslimWorldLeague, .shafi),
            ("Central Asia", CLLocationCoordinate2D(latitude: 41.0082, longitude: 28.9784), nil, .muslimWorldLeague, .hanafi),
            ("Europe", CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278), nil, .muslimWorldLeague, .hanafi)
        ]

        for (regionName, coordinate, countryName, expectedMethod, expectedMadhab) in testCases {
            let config = provider.configuration(
                coordinate: coordinate,
                countryName: countryName
            )
            XCTAssertEqual(config.calculationMethod, expectedMethod,
                          "\(regionName) should use \(expectedMethod.rawValue)")
            XCTAssertEqual(config.madhab, expectedMadhab,
                          "\(regionName) should use \(expectedMadhab.rawValue) madhab")
        }

        print("✅ All regions have valid configuration")
    }

    // MARK: - Madhab Distribution Test

    func testMadhabDistributionMatchesIslamicDemographics() throws {
        // Hanafi regions: North America, South Asia, Central Asia, Europe
        let hanafiRegions = ["United States", "Pakistan", "Turkey", "United Kingdom"]
        for country in hanafiRegions {
            let config = provider.configuration(coordinate: nil, countryName: country)
            XCTAssertEqual(config.madhab, .hanafi,
                          "\(country) should use Hanafi madhab")
        }

        // Shafi regions: North Africa, Gulf States, Southeast Asia, East Africa, Middle East
        let shafiRegions = ["Egypt", "Saudi Arabia", "Indonesia", "Kenya", "Jordan"]
        for country in shafiRegions {
            let config = provider.configuration(coordinate: nil, countryName: country)
            XCTAssertEqual(config.madhab, .shafi,
                          "\(country) should use Shafi madhab")
        }

        print("✅ Madhab distribution matches Islamic demographics")
    }

    // MARK: - Calculation Method Accuracy Test

    func testCalculationMethodsMatchRegionalStandards() throws {
        let testCases: [(String, CalculationMethod)] = [
            ("United States", .northAmerica),
            ("Canada", .northAmerica),
            ("Pakistan", .karachi),
            ("India", .karachi),
            ("Egypt", .egyptian),
            ("Morocco", .egyptian),
            ("Saudi Arabia", .ummAlQura),
            ("United Arab Emirates", .ummAlQura),
            ("Indonesia", .singapore),
            ("Malaysia", .singapore),
            ("Singapore", .singapore)
        ]

        for (country, expectedMethod) in testCases {
            let config = provider.configuration(coordinate: nil, countryName: country)
            XCTAssertEqual(config.calculationMethod, expectedMethod,
                          "\(country) should use \(expectedMethod.rawValue) calculation method")
        }

        print("✅ Calculation methods match regional standards")
    }
}
