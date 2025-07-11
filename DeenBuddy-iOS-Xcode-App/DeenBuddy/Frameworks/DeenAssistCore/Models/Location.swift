import Foundation
import CoreLocation

// MARK: - Location Models

public struct LocationCoordinate: Codable, Equatable, Sendable {
    public let latitude: Double
    public let longitude: Double
    
    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
    
    public init(from clLocation: CLLocationCoordinate2D) {
        self.latitude = clLocation.latitude
        self.longitude = clLocation.longitude
    }
    
    public var clLocationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

public struct LocationInfo: Codable, Equatable {
    public let coordinate: LocationCoordinate
    public let accuracy: Double
    public let timestamp: Date
    public let city: String?
    public let country: String?
    
    public init(
        coordinate: LocationCoordinate,
        accuracy: Double,
        timestamp: Date = Date(),
        city: String? = nil,
        country: String? = nil
    ) {
        self.coordinate = coordinate
        self.accuracy = accuracy
        self.timestamp = timestamp
        self.city = city
        self.country = country
    }
}

// LocationError is defined in LocationServiceProtocol.swift

public enum LocationPermissionStatus {
    case notDetermined
    case denied
    case restricted
    case authorizedWhenInUse
    case authorizedAlways
    
    public var isAuthorized: Bool {
        switch self {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        default:
            return false
        }
    }
}

// MARK: - Qibla Direction

