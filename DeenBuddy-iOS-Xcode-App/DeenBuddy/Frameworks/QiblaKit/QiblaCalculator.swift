import Foundation
import CoreLocation
import CoreMotion

/// A comprehensive Qibla direction calculator with high precision
public class QiblaCalculator {
    
    // MARK: - Constants
    
    /// Coordinates of the Kaaba in Mecca
    public static let kaabaCoordinate = CLLocationCoordinate2D(
        latitude: 21.422487,
        longitude: 39.826206
    )
    
    /// Earth's radius in kilometers
    private static let earthRadiusKm: Double = 6371.0
    
    // MARK: - Public Methods
    
    /// Calculate the Qibla direction from a given location
    /// - Parameter from: The location to calculate Qibla direction from
    /// - Returns: QiblaResult containing direction, distance, and metadata
    public static func calculateQibla(from location: CLLocationCoordinate2D) -> QiblaResult {
        let direction = calculateBearing(from: location, to: kaabaCoordinate)
        let distance = calculateDistance(from: location, to: kaabaCoordinate)
        let magneticDeclination = getMagneticDeclination(for: location)
        
        return QiblaResult(
            direction: direction,
            distance: distance,
            fromLocation: location,
            magneticDeclination: magneticDeclination,
            calculatedAt: Date()
        )
    }
    
    /// Calculate the great circle bearing between two coordinates
    /// - Parameters:
    ///   - from: Starting coordinate
    ///   - to: Destination coordinate
    /// - Returns: Bearing in degrees (0-360, where 0 is North)
    public static func calculateBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude.toRadians()
        let lat2 = to.latitude.toRadians()
        let deltaLon = (to.longitude - from.longitude).toRadians()
        
        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        
        let bearing = atan2(y, x).toDegrees()
        
        // Normalize to 0-360 degrees
        return bearing < 0 ? bearing + 360 : bearing
    }
    
    /// Calculate the great circle distance between two coordinates
    /// - Parameters:
    ///   - from: Starting coordinate
    ///   - to: Destination coordinate
    /// - Returns: Distance in kilometers
    public static func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude.toRadians()
        let lat2 = to.latitude.toRadians()
        let deltaLat = (to.latitude - from.latitude).toRadians()
        let deltaLon = (to.longitude - from.longitude).toRadians()
        
        let a = sin(deltaLat / 2) * sin(deltaLat / 2) +
                cos(lat1) * cos(lat2) *
                sin(deltaLon / 2) * sin(deltaLon / 2)
        
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        
        return earthRadiusKm * c
    }
    
    /// Apply magnetic declination correction to compass bearing
    /// - Parameters:
    ///   - compassBearing: Raw compass bearing in degrees
    ///   - magneticDeclination: Magnetic declination in degrees (positive for East, negative for West)
    /// - Returns: True bearing corrected for magnetic declination
    public static func applyMagneticDeclination(
        compassBearing: Double,
        magneticDeclination: Double
    ) -> Double {
        let correctedBearing = compassBearing + magneticDeclination
        return correctedBearing < 0 ? correctedBearing + 360 : 
               correctedBearing >= 360 ? correctedBearing - 360 : correctedBearing
    }
    
    /// Get magnetic declination for a given location and date using the World Magnetic Model
    /// - Parameters:
    ///   - location: The location to get declination for
    ///   - date: The date for the calculation (defaults to current date)
    /// - Returns: Magnetic declination in degrees
    public static func getMagneticDeclination(
        for location: CLLocationCoordinate2D,
        on date: Date = Date()
    ) -> Double {
        // Use World Magnetic Model for accurate declination calculation
        return WorldMagneticModel.calculateMagneticDeclination(for: location, on: date)
    }
    
    /// Validate if coordinates are valid
    /// - Parameter coordinate: The coordinate to validate
    /// - Returns: True if the coordinate is valid
    public static func isValidCoordinate(_ coordinate: CLLocationCoordinate2D) -> Bool {
        return CLLocationCoordinate2DIsValid(coordinate) &&
               coordinate.latitude >= -90 && coordinate.latitude <= 90 &&
               coordinate.longitude >= -180 && coordinate.longitude <= 180
    }
    
    /// Calculate Qibla direction with compass heading correction
    /// - Parameters:
    ///   - location: User's location
    ///   - compassHeading: Current compass heading in degrees
    /// - Returns: QiblaResult with compass-corrected direction
    public static func calculateQiblaWithCompass(
        from location: CLLocationCoordinate2D,
        compassHeading: Double
    ) -> QiblaResult {
        let qiblaResult = calculateQibla(from: location)
        
        // The compass heading is already magnetic, so we need to apply declination
        // to get the true direction difference
        let trueBearing = applyMagneticDeclination(
            compassBearing: qiblaResult.direction,
            magneticDeclination: qiblaResult.magneticDeclination
        )
        
        return QiblaResult(
            direction: trueBearing,
            distance: qiblaResult.distance,
            fromLocation: location,
            magneticDeclination: qiblaResult.magneticDeclination,
            calculatedAt: Date()
        )
    }
    
    /// Get magnetic field strength at a location
    /// - Parameter location: Location to get field strength for
    /// - Returns: Magnetic field strength in nanotesla
    public static func getMagneticFieldStrength(for location: CLLocationCoordinate2D) -> Double {
        return WorldMagneticModel.getMagneticFieldStrength(for: location)
    }
    
    /// Check if the WMM model is valid for the given date
    /// - Parameter date: Date to check
    /// - Returns: True if date is within valid model range
    public static func isValidModelDate(_ date: Date) -> Bool {
        return WorldMagneticModel.isValidModelDate(date)
    }
    
    /// Calculate the angular difference between two bearings
    /// - Parameters:
    ///   - bearing1: First bearing in degrees
    ///   - bearing2: Second bearing in degrees
    /// - Returns: Angular difference in degrees (-180 to 180)
    public static func angularDifference(from bearing1: Double, to bearing2: Double) -> Double {
        var diff = bearing2 - bearing1
        
        // Normalize to -180 to 180 range
        while diff > 180 { diff -= 360 }
        while diff < -180 { diff += 360 }
        
        return diff
    }
}

// MARK: - Extensions

extension Double {
    /// Convert degrees to radians
    func toRadians() -> Double {
        return self * .pi / 180.0
    }
    
    /// Convert radians to degrees
    func toDegrees() -> Double {
        return self * 180.0 / .pi
    }
}

// MARK: - QiblaResult

/// Result of a Qibla calculation
public struct QiblaResult {
    /// Direction to Qibla in degrees (0-360, where 0 is North)
    public let direction: Double
    
    /// Distance to Kaaba in kilometers
    public let distance: Double
    
    /// The location from which Qibla was calculated
    public let fromLocation: CLLocationCoordinate2D
    
    /// Magnetic declination at the location in degrees
    public let magneticDeclination: Double
    
    /// When the calculation was performed
    public let calculatedAt: Date
    
    /// Initialize QiblaResult with all parameters
    public init(direction: Double, distance: Double, fromLocation: CLLocationCoordinate2D, magneticDeclination: Double, calculatedAt: Date) {
        self.direction = direction
        self.distance = distance
        self.fromLocation = fromLocation
        self.magneticDeclination = magneticDeclination
        self.calculatedAt = calculatedAt
    }
    
    /// Initialize QiblaResult with automatic magnetic declination calculation
    public init(direction: Double, distance: Double, fromLocation: CLLocationCoordinate2D, calculatedAt: Date) {
        self.direction = direction
        self.distance = distance
        self.fromLocation = fromLocation
        self.magneticDeclination = QiblaCalculator.getMagneticDeclination(for: fromLocation)
        self.calculatedAt = calculatedAt
    }
    
    /// Direction formatted as a compass bearing (e.g., "NE", "SW")
    public var compassBearing: String {
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                         "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int((direction + 11.25) / 22.5) % 16
        return directions[index]
    }
    
    /// Distance formatted as a human-readable string
    public var formattedDistance: String {
        if distance < 1 {
            return String(format: "%.0f m", distance * 1000)
        } else if distance < 100 {
            return String(format: "%.1f km", distance)
        } else {
            return String(format: "%.0f km", distance)
        }
    }
    
    /// Direction formatted as degrees with cardinal direction
    public var formattedDirection: String {
        return String(format: "%.1f° %@", direction, compassBearing)
    }
    
    /// True bearing corrected for magnetic declination
    public var trueBearing: Double {
        return QiblaCalculator.applyMagneticDeclination(
            compassBearing: direction,
            magneticDeclination: magneticDeclination
        )
    }
    
    /// Formatted magnetic declination
    public var formattedMagneticDeclination: String {
        return WorldMagneticModel.formatDeclination(magneticDeclination)
    }
    
    /// Comprehensive direction information including magnetic declination
    public var detailedDirectionInfo: String {
        return "True: \(formattedDirection)\nMagnetic Declination: \(formattedMagneticDeclination)\nCompass: \(String(format: "%.1f°", trueBearing))"
    }
}

// MARK: - QiblaError

/// Errors that can occur during Qibla calculations
public enum QiblaError: Error, LocalizedError {
    case invalidCoordinate
    case calculationFailed
    case locationUnavailable
    
    public var errorDescription: String? {
        switch self {
        case .invalidCoordinate:
            return "Invalid coordinate provided"
        case .calculationFailed:
            return "Failed to calculate Qibla direction"
        case .locationUnavailable:
            return "Location is not available"
        }
    }
}
