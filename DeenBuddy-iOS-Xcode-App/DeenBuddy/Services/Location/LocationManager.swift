import Foundation
import CoreLocation
import SwiftUI

// MARK: - Location Manager

public class LocationManager: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    private var locationCompletion: ((Result<CLLocation, LocationError>) -> Void)?
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    
    public override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestLocationPermission(completion: @escaping (Result<CLLocation, LocationError>) -> Void) {
        locationCompletion = completion
        
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            completion(.failure(.permissionDenied))
        case .authorizedWhenInUse, .authorizedAlways:
            getCurrentLocation(completion: completion)
        @unknown default:
            completion(.failure(.permissionDenied))
        }
    }
    
    private func getCurrentLocation(completion: @escaping (Result<CLLocation, LocationError>) -> Void) {
        guard CLLocationManager.locationServicesEnabled() else {
            completion(.failure(.locationUnavailable))
            return
        }
        
        locationCompletion = completion
        locationManager.requestLocation()
        
        // Set timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
            if self?.locationCompletion != nil {
                self?.locationCompletion?(.failure(.timeout))
                self?.locationCompletion = nil
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        DispatchQueue.main.async {
            self.currentLocation = location
            self.locationCompletion?(.success(location))
            self.locationCompletion = nil
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    self.locationCompletion?(.failure(.permissionDenied))
                case .locationUnknown:
                    self.locationCompletion?(.failure(.locationUnavailable))
                case .network:
                    self.locationCompletion?(.failure(.networkError))
                default:
                    self.locationCompletion?(.failure(.locationUnavailable))
                }
            } else {
                self.locationCompletion?(.failure(.locationUnavailable))
            }
            self.locationCompletion = nil
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status
            
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                if let completion = self.locationCompletion {
                    self.getCurrentLocation(completion: completion)
                }
            case .denied, .restricted:
                self.locationCompletion?(.failure(.permissionDenied))
                self.locationCompletion = nil
            default:
                break
            }
        }
    }
}

// MARK: - Compass Manager

class CompassManager: NSObject, ObservableObject {
    @Published var heading: Double = 0
    @Published var accuracy: CompassAccuracy = .unknown
    
    private let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        locationManager.delegate = self
    }
    
    func startUpdating() {
        guard CLLocationManager.headingAvailable() else { return }
        locationManager.startUpdatingHeading()
    }
    
    func stopUpdating() {
        locationManager.stopUpdatingHeading()
    }
}

// MARK: - CLLocationManagerDelegate for Compass

extension CompassManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        DispatchQueue.main.async {
            self.heading = newHeading.magneticHeading
            
            // Update accuracy based on heading accuracy
            if newHeading.headingAccuracy < 0 {
                self.accuracy = .unknown
            } else if newHeading.headingAccuracy < 5 {
                self.accuracy = .high
            } else if newHeading.headingAccuracy < 15 {
                self.accuracy = .medium
            } else {
                self.accuracy = .low
            }
        }
    }
}
