import Foundation
import CoreLocation

// MARK: - Location Models
// LocationCoordinate and LocationInfo are now defined in LocationServiceProtocol.swift
// Import them from there to avoid duplication

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

