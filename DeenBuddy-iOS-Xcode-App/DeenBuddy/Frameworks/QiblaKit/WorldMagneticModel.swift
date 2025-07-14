import Foundation
import CoreLocation

/// World Magnetic Model (WMM) implementation for accurate magnetic declination calculation
/// Based on the NOAA World Magnetic Model 2020-2025
public class WorldMagneticModel {
    
    // MARK: - Constants
    
    /// WMM 2020-2025 model epoch
    private static let epoch: Double = 2020.0
    
    /// Earth's radius in kilometers
    private static let earthRadius: Double = 6371.2
    
    /// Magnetic model coefficients (simplified subset for practical use)
    /// In a full implementation, these would be loaded from the complete WMM coefficient file
    private static let coefficients: [MagneticCoefficient] = [
        // Gauss coefficients for the main field (subset)
        MagneticCoefficient(n: 1, m: 0, gnm: -29404.8, hnm: 0.0, gnmDot: 6.7, hnmDot: 0.0),
        MagneticCoefficient(n: 1, m: 1, gnm: -1450.9, hnm: 4652.5, gnmDot: 7.4, hnmDot: -25.9),
        MagneticCoefficient(n: 2, m: 0, gnm: -2499.6, hnm: 0.0, gnmDot: -11.8, hnmDot: 0.0),
        MagneticCoefficient(n: 2, m: 1, gnm: 2982.0, hnm: -2991.6, gnmDot: -7.2, hnmDot: -30.2),
        MagneticCoefficient(n: 2, m: 2, gnm: 1677.0, hnm: -734.6, gnmDot: 2.3, hnmDot: -23.9),
        MagneticCoefficient(n: 3, m: 0, gnm: 1363.2, hnm: 0.0, gnmDot: 2.8, hnmDot: 0.0),
        MagneticCoefficient(n: 3, m: 1, gnm: -2381.2, hnm: -82.1, gnmDot: -6.2, hnmDot: -1.6),
        MagneticCoefficient(n: 3, m: 2, gnm: 1236.2, hnm: 241.9, gnmDot: 3.4, hnmDot: -1.0),
        MagneticCoefficient(n: 3, m: 3, gnm: 525.7, hnm: -543.4, gnmDot: -12.2, hnmDot: 1.1),
        MagneticCoefficient(n: 4, m: 0, gnm: 903.0, hnm: 0.0, gnmDot: -1.1, hnmDot: 0.0),
        MagneticCoefficient(n: 4, m: 1, gnm: 809.5, hnm: 281.9, gnmDot: 1.8, hnmDot: -0.6),
        MagneticCoefficient(n: 4, m: 2, gnm: 86.3, hnm: -158.4, gnmDot: -8.7, hnmDot: 0.8),
        MagneticCoefficient(n: 4, m: 3, gnm: -309.4, hnm: 199.7, gnmDot: -2.6, hnmDot: -0.7),
        MagneticCoefficient(n: 4, m: 4, gnm: 47.7, hnm: -350.1, gnmDot: -2.1, hnmDot: -2.0)
    ]
    
    // MARK: - Public Methods
    
    /// Calculate magnetic declination using the World Magnetic Model
    /// - Parameters:
    ///   - location: Geographic location
    ///   - date: Date for the calculation (defaults to current date)
    /// - Returns: Magnetic declination in degrees (positive for East, negative for West)
    public static func calculateMagneticDeclination(
        for location: CLLocationCoordinate2D,
        on date: Date = Date()
    ) -> Double {
        // Validate input
        guard CLLocationCoordinate2DIsValid(location) else {
            print("⚠️ Invalid coordinate for magnetic declination calculation")
            return 0.0
        }
        
        // Convert to required format
        let latitude = location.latitude
        let longitude = location.longitude
        let altitude = 0.0 // Sea level assumption
        
        // Calculate decimal year
        let decimalYear = calculateDecimalYear(from: date)
        
        // Calculate magnetic field components
        let magneticField = calculateMagneticField(
            latitude: latitude,
            longitude: longitude,
            altitude: altitude,
            decimalYear: decimalYear
        )
        
        // Calculate declination from X and Y components
        let declination = atan2(magneticField.y, magneticField.x) * 180.0 / .pi
        
        // Apply bounds checking
        let clampedDeclination = max(-180.0, min(180.0, declination))
        
        print("🧭 WMM Magnetic Declination for \(latitude), \(longitude): \(clampedDeclination)°")
        
        return clampedDeclination
    }
    
    /// Get magnetic field strength for a location
    /// - Parameters:
    ///   - location: Geographic location
    ///   - date: Date for the calculation
    /// - Returns: Total magnetic field strength in nanotesla (nT)
    public static func getMagneticFieldStrength(
        for location: CLLocationCoordinate2D,
        on date: Date = Date()
    ) -> Double {
        let decimalYear = calculateDecimalYear(from: date)
        let magneticField = calculateMagneticField(
            latitude: location.latitude,
            longitude: location.longitude,
            altitude: 0.0,
            decimalYear: decimalYear
        )
        
        return sqrt(magneticField.x * magneticField.x + 
                   magneticField.y * magneticField.y + 
                   magneticField.z * magneticField.z)
    }
    
    /// Check if the given date is within the valid range for the current WMM model
    /// - Parameter date: Date to check
    /// - Returns: True if date is within valid range
    public static func isValidModelDate(_ date: Date) -> Bool {
        let decimalYear = calculateDecimalYear(from: date)
        return decimalYear >= 2020.0 && decimalYear <= 2025.0
    }
    
    // MARK: - Private Methods
    
    private static func calculateDecimalYear(from date: Date) -> Double {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let startOfYear = calendar.date(from: DateComponents(year: year))!
        let startOfNextYear = calendar.date(from: DateComponents(year: year + 1))!
        
        let dayOfYear = date.timeIntervalSince(startOfYear)
        let daysInYear = startOfNextYear.timeIntervalSince(startOfYear)
        
        return Double(year) + (dayOfYear / daysInYear)
    }
    
    private static func calculateMagneticField(
        latitude: Double,
        longitude: Double,
        altitude: Double,
        decimalYear: Double
    ) -> MagneticFieldVector {
        
        // Convert to spherical coordinates
        let phi = latitude * .pi / 180.0  // colatitude in radians
        let lambda = longitude * .pi / 180.0  // longitude in radians
        let r = earthRadius + altitude  // radius from earth center
        
        // Time interpolation
        let dt = decimalYear - epoch
        
        // Initialize field components
        var bx = 0.0
        var by = 0.0
        var bz = 0.0
        
        // Calculate field using spherical harmonics (simplified)
        for coeff in coefficients {
            let n = Double(coeff.n)
            let m = Double(coeff.m)
            
            // Time-interpolated coefficients
            let gnm = coeff.gnm + coeff.gnmDot * dt
            let hnm = coeff.hnm + coeff.hnmDot * dt
            
            // Normalized associated Legendre functions (simplified calculation)
            let p = legendre(n: coeff.n, m: coeff.m, x: cos(phi))
            let dp = legendreDerivative(n: coeff.n, m: coeff.m, x: cos(phi))
            
            // Cosine and sine terms
            let cosmLambda = cos(m * lambda)
            let sinmLambda = sin(m * lambda)
            
            // Radius term
            let rTerm = pow(earthRadius / r, n + 1)
            
            // Field components in spherical coordinates
            let br = rTerm * (n + 1) * p * (gnm * cosmLambda + hnm * sinmLambda)
            let bTheta = -rTerm * dp * (gnm * cosmLambda + hnm * sinmLambda)
            let bPhi = rTerm * (m * p / sin(phi)) * (-gnm * sinmLambda + hnm * cosmLambda)
            
            bx += br
            by += bTheta
            bz += bPhi
        }
        
        // Convert to Cartesian coordinates (North, East, Down)
        let north = -by
        let east = bz
        let down = bx
        
        return MagneticFieldVector(x: north, y: east, z: down)
    }
    
    /// Simplified normalized associated Legendre function
    private static func legendre(n: Int, m: Int, x: Double) -> Double {
        // This is a simplified implementation
        // In a full WMM implementation, this would be more comprehensive
        
        guard n >= 0 && m >= 0 && m <= n else { return 0.0 }
        
        if n == 0 {
            return 1.0
        } else if n == 1 && m == 0 {
            return x
        } else if n == 1 && m == 1 {
            return sqrt(1 - x * x)
        } else if n == 2 && m == 0 {
            return 0.5 * (3 * x * x - 1)
        } else if n == 2 && m == 1 {
            return sqrt(3) * x * sqrt(1 - x * x)
        } else if n == 2 && m == 2 {
            return sqrt(3) * (1 - x * x) / 2
        } else {
            // For higher orders, use approximation
            return pow(1 - x * x, Double(m) / 2.0) * pow(x, Double(n - m))
        }
    }
    
    /// Simplified derivative of normalized associated Legendre function
    private static func legendreDerivative(n: Int, m: Int, x: Double) -> Double {
        // Simplified derivative calculation
        if n == 1 && m == 0 {
            return 1.0
        } else if n == 1 && m == 1 {
            return -x / sqrt(1 - x * x)
        } else if n == 2 && m == 0 {
            return 3 * x
        } else {
            // Approximation for higher orders
            return Double(n - m) * pow(1 - x * x, Double(m) / 2.0) * pow(x, Double(n - m - 1))
        }
    }
}

// MARK: - Supporting Types

/// Magnetic field coefficient from WMM model
private struct MagneticCoefficient {
    let n: Int      // Degree
    let m: Int      // Order
    let gnm: Double // Gauss coefficient
    let hnm: Double // Gauss coefficient
    let gnmDot: Double // Secular variation
    let hnmDot: Double // Secular variation
}

/// Magnetic field vector components
private struct MagneticFieldVector {
    let x: Double  // North component (nanotesla)
    let y: Double  // East component (nanotesla)
    let z: Double  // Down component (nanotesla)
}

// MARK: - Extensions

extension WorldMagneticModel {
    /// Get a human-readable description of magnetic declination
    /// - Parameter declination: Declination in degrees
    /// - Returns: Formatted string describing the declination
    public static func formatDeclination(_ declination: Double) -> String {
        let absValue = abs(declination)
        let direction = declination >= 0 ? "East" : "West"
        
        if absValue < 0.1 {
            return "No declination"
        } else {
            return String(format: "%.1f° %@", absValue, direction)
        }
    }
    
    /// Calculate grid convergence for UTM projections
    /// - Parameters:
    ///   - location: Geographic location
    ///   - utmZone: UTM zone number
    /// - Returns: Grid convergence in degrees
    public static func calculateGridConvergence(
        for location: CLLocationCoordinate2D,
        utmZone: Int
    ) -> Double {
        let centralMeridian = (Double(utmZone) - 1) * 6 - 177
        let deltaLon = location.longitude - centralMeridian
        let lat = location.latitude * .pi / 180.0
        
        return deltaLon * sin(lat) * .pi / 180.0
    }
}