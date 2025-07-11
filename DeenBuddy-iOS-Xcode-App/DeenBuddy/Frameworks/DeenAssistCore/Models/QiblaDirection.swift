import Foundation

// MARK: - Qibla Direction Models

public struct QiblaDirection: Codable, Equatable {
    public let direction: Double // Degrees from North (0-360)
    public let distance: Double // Distance to Kaaba in kilometers
    public let location: LocationCoordinate
    public let timestamp: Date
    
    public init(
        direction: Double,
        distance: Double,
        location: LocationCoordinate,
        timestamp: Date = Date()
    ) {
        self.direction = direction
        self.distance = distance
        self.location = location
        self.timestamp = timestamp
    }
    
    public var directionRadians: Double {
        return direction * .pi / 180.0
    }
    
    public var compassDirection: String {
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                         "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int((direction + 11.25) / 22.5) % 16
        return directions[index]
    }
    
    public var formattedDistance: String {
        if distance < 1000 {
            return String(format: "%.0f km", distance)
        } else {
            return String(format: "%.1f km", distance)
        }
    }

    /// Calculate Qibla direction from a given coordinate
    public static func calculate(from location: LocationCoordinate) -> QiblaDirection {
        return KaabaLocation.calculateDirection(from: location)
    }
}

// MARK: - Kaaba Constants

public struct KaabaLocation {
    public static let coordinate = LocationCoordinate(
        latitude: 21.4225, // Kaaba latitude
        longitude: 39.8262 // Kaaba longitude
    )
    
    public static func calculateDirection(from location: LocationCoordinate) -> QiblaDirection {
        let lat1 = location.latitude * .pi / 180
        let lat2 = KaabaLocation.coordinate.latitude * .pi / 180
        let deltaLon = (KaabaLocation.coordinate.longitude - location.longitude) * .pi / 180
        
        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        
        var bearing = atan2(y, x) * 180 / .pi
        bearing = (bearing + 360).truncatingRemainder(dividingBy: 360)
        
        let distance = calculateDistance(from: location, to: KaabaLocation.coordinate)
        
        return QiblaDirection(
            direction: bearing,
            distance: distance,
            location: location
        )
    }
    
    private static func calculateDistance(from: LocationCoordinate, to: LocationCoordinate) -> Double {
        let earthRadius = 6371.0 // Earth's radius in kilometers
        
        let lat1Rad = from.latitude * .pi / 180
        let lat2Rad = to.latitude * .pi / 180
        let deltaLatRad = (to.latitude - from.latitude) * .pi / 180
        let deltaLonRad = (to.longitude - from.longitude) * .pi / 180
        
        let a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
                cos(lat1Rad) * cos(lat2Rad) *
                sin(deltaLonRad / 2) * sin(deltaLonRad / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        
        return earthRadius * c
    }
}
