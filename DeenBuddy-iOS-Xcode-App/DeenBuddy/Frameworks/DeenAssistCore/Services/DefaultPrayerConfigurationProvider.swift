import Foundation
import CoreLocation

/// Geographic regions for determining default prayer configurations
public enum GeographicRegion {
    case northAmerica
    case southAsia
    case northAfrica
    case gulfStates
    case southeastAsia
    case eastAfrica
    case middleEast
    case centralAsia
    case europe
    case other
    
    /// Default madhab for this region based on prevalent practice
    var defaultMadhab: Madhab {
        switch self {
        case .northAmerica:
            return .hanafi // Large South Asian diaspora
        case .southAsia:
            return .hanafi // Pakistan, India, Bangladesh, Afghanistan
        case .northAfrica:
            return .shafi // Egypt, Libya, Tunisia, Algeria (Maliki represented by shafi)
        case .gulfStates:
            return .shafi // Saudi Arabia, UAE, Kuwait (Hanbali represented by shafi)
        case .southeastAsia:
            return .shafi // Indonesia, Malaysia, Brunei, Singapore
        case .eastAfrica:
            return .shafi // Somalia, Kenya, Tanzania, Uganda
        case .middleEast:
            return .shafi // Jordan, Palestine, Lebanon, Syria
        case .centralAsia:
            return .hanafi // Turkey, Kazakhstan, Uzbekistan, Turkmenistan
        case .europe:
            return .hanafi // Large Turkish and South Asian communities
        case .other:
            return .shafi // Conservative default (most common globally)
        }
    }
}

/// Default prayer settings derived from regional heuristics
public struct DefaultPrayerConfiguration {
    public let calculationMethod: CalculationMethod
    public let madhab: Madhab
}

/// Provides sensible defaults for onboarding based on coarse geography
public struct DefaultPrayerConfigurationProvider {
    
    // MARK: - Region Code Sets
    
    private static let northAmericanRegionCodes: Set<String> = [
        "US", "CA", "MX", "GL", "BM", "BS", "BB", "AG", "AI", "AW", "BZ", "CR",
        "PA", "DO", "PR", "KN", "LC", "VC", "TT", "HT", "JM", "GD", "KY", "TC",
        "VG", "VI", "DM", "SV", "GT", "HN", "NI", "CU", "SX", "BQ"
    ]
    
    private static let southAsianRegionCodes: Set<String> = [
        "PK", "IN", "BD", "AF", "LK", "NP", "BT", "MV"
    ]
    
    private static let northAfricanRegionCodes: Set<String> = [
        "EG", "LY", "TN", "DZ", "MA", "MR", "SD", "SS"
    ]
    
    private static let gulfStatesRegionCodes: Set<String> = [
        "SA", "AE", "KW", "QA", "BH", "OM", "YE"
    ]
    
    private static let southeastAsianRegionCodes: Set<String> = [
        "ID", "MY", "SG", "BN", "PH", "TH", "MM", "KH", "VN", "LA"
    ]
    
    private static let eastAfricanRegionCodes: Set<String> = [
        "SO", "KE", "TZ", "UG", "ET", "ER", "DJ", "RW", "BI", "MZ", "MG", "KM", "SC", "ZW", "ZM", "MW"
    ]
    
    private static let middleEastRegionCodes: Set<String> = [
        "JO", "PS", "LB", "SY", "IQ", "IL"
    ]
    
    private static let centralAsianRegionCodes: Set<String> = [
        "TR", "KZ", "UZ", "TM", "KG", "TJ", "AZ", "GE", "AM"
    ]
    
    private static let europeanRegionCodes: Set<String> = [
        "GB", "FR", "DE", "NL", "BE", "AT", "CH", "IT", "ES", "PT", "SE", "NO",
        "DK", "FI", "IE", "PL", "CZ", "SK", "HU", "RO", "BG", "GR", "HR", "SI",
        "AL", "BA", "RS", "ME", "MK", "XK"
    ]

    private let locale: Locale

    public init(locale: Locale = .current) {
        self.locale = locale
    }

    /// Returns the default configuration for a user based on their coordinate/country/locale.
    public func configuration(
        coordinate: CLLocationCoordinate2D?,
        countryName: String?
    ) -> DefaultPrayerConfiguration {
        let region = determineRegion(
            coordinate: coordinate,
            countryName: countryName,
            localeRegionCode: locale.regionCode
        )
        
        let madhab = region.defaultMadhab
        let calculationMethod = self.calculationMethod(for: region)

        return DefaultPrayerConfiguration(
            calculationMethod: calculationMethod,
            madhab: madhab
        )
    }

    /// Returns the appropriate calculation method for a given region
    private func calculationMethod(for region: GeographicRegion) -> CalculationMethod {
        switch region {
        case .northAmerica:
            return .northAmerica
        case .southAsia:
            return .karachi
        case .northAfrica:
            return .egyptian
        case .gulfStates:
            return .ummAlQura
        case .southeastAsia:
            return .singapore
        case .middleEast:
            return .muslimWorldLeague
        case .eastAfrica:
            return .muslimWorldLeague
        case .centralAsia:
            return .muslimWorldLeague
        case .europe:
            return .muslimWorldLeague
        case .other:
            return .muslimWorldLeague
        }
    }

    // MARK: - Helpers
    
    /// Determine the geographic region based on available information
    private func determineRegion(
        coordinate: CLLocationCoordinate2D?,
        countryName: String?,
        localeRegionCode: String?
    ) -> GeographicRegion {
        // Try to determine region from country code (most reliable)
        if let countryCode = getRegionCode(countryName: countryName, localeRegionCode: localeRegionCode) {
            if let region = regionFromCountryCode(countryCode) {
                return region
            }
        }
        
        // Fallback to coordinate-based detection
        if let coordinate = coordinate {
            if let region = regionFromCoordinate(coordinate) {
                return region
            }
        }
        
        return .other
    }
    
    /// Get region code from country name or locale
    private func getRegionCode(countryName: String?, localeRegionCode: String?) -> String? {
        if let countryName = countryName,
           let code = regionCode(forCountryName: countryName) {
            return code
        }
        
        if let code = localeRegionCode?.uppercased() {
            return code
        }
        
        return nil
    }
    
    /// Map country code to geographic region
    private func regionFromCountryCode(_ code: String) -> GeographicRegion? {
        let upperCode = code.uppercased()
        
        if Self.northAmericanRegionCodes.contains(upperCode) {
            return .northAmerica
        } else if Self.southAsianRegionCodes.contains(upperCode) {
            return .southAsia
        } else if Self.northAfricanRegionCodes.contains(upperCode) {
            return .northAfrica
        } else if Self.gulfStatesRegionCodes.contains(upperCode) {
            return .gulfStates
        } else if Self.southeastAsianRegionCodes.contains(upperCode) {
            return .southeastAsia
        } else if Self.eastAfricanRegionCodes.contains(upperCode) {
            return .eastAfrica
        } else if Self.middleEastRegionCodes.contains(upperCode) {
            return .middleEast
        } else if Self.centralAsianRegionCodes.contains(upperCode) {
            return .centralAsia
        } else if Self.europeanRegionCodes.contains(upperCode) {
            return .europe
        }
        
        return nil
    }
    
    /// Determine region from coordinate (rough approximation)
    private func regionFromCoordinate(_ coordinate: CLLocationCoordinate2D) -> GeographicRegion? {
        let lat = coordinate.latitude
        let lon = coordinate.longitude
        
        // North America
        if lat >= 7 && lat <= 84 && lon >= -180 && lon <= -52 {
            return .northAmerica
        }
        
        // South Asia
        if lat >= 5 && lat <= 40 && lon >= 60 && lon <= 95 {
            return .southAsia
        }
        
        // Southeast Asia
        if lat >= -10 && lat <= 25 && lon >= 95 && lon <= 140 {
            return .southeastAsia
        }
        
        // North Africa
        if lat >= 15 && lat <= 37 && lon >= -18 && lon <= 37 {
            return .northAfrica
        }
        
        // Gulf States
        if lat >= 12 && lat <= 32 && lon >= 34 && lon <= 60 {
            return .gulfStates
        }
        
        // Middle East
        if lat >= 29 && lat <= 37 && lon >= 34 && lon <= 48 {
            return .middleEast
        }
        
        // Central Asia
        if lat >= 35 && lat <= 55 && lon >= 26 && lon <= 87 {
            return .centralAsia
        }
        
        // Europe
        if lat >= 35 && lat <= 71 && lon >= -10 && lon <= 40 {
            return .europe
        }
        
        // East Africa
        if lat >= -15 && lat <= 18 && lon >= 20 && lon <= 52 {
            return .eastAfrica
        }
        
        return nil
    }

    private func regionCode(forCountryName name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let target = trimmed.lowercased()

        for code in Locale.isoRegionCodes {
            if let localizedName = locale.localizedString(forRegionCode: code)?
                .lowercased(),
               localizedName == target {
                return code.uppercased()
            }
        }

        return nil
    }
}
