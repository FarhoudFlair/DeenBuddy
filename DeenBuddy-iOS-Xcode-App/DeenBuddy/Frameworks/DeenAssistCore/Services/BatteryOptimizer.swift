import Foundation
import CoreLocation
import Combine
import UIKit

/// Service for optimizing battery usage, especially for location services
@MainActor
public class BatteryOptimizer: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var batteryLevel: Float = 1.0
    @Published public var batteryState: UIDevice.BatteryState = .unknown
    @Published public var isLowPowerModeEnabled = false
    @Published public var optimizationLevel: OptimizationLevel = .balanced
    @Published public var locationUpdateStrategy: LocationUpdateStrategy = .adaptive
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let device = UIDevice.current
    private var lastLocationUpdate = Date()
    private var locationUpdateTimer: Timer?
    
    // MARK: - Singleton
    
    public static let shared = BatteryOptimizer()
    
    private init() {
        setupBatteryMonitoring()
        setupLowPowerModeObserver()
        determineOptimizationLevel()
    }
    
    deinit {
        locationUpdateTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    
    /// Get optimized location accuracy based on battery state
    public func getOptimizedLocationAccuracy() -> CLLocationAccuracy {
        switch optimizationLevel {
        case .performance:
            return kCLLocationAccuracyBest
        case .balanced:
            return kCLLocationAccuracyNearestTenMeters
        case .batterySaver:
            return kCLLocationAccuracyHundredMeters
        case .extreme:
            return kCLLocationAccuracyKilometer
        }
    }
    
    /// Get optimized location update interval
    public func getOptimizedUpdateInterval() -> TimeInterval {
        switch optimizationLevel {
        case .performance:
            return 30.0 // 30 seconds
        case .balanced:
            return 60.0 // 1 minute
        case .batterySaver:
            return 300.0 // 5 minutes
        case .extreme:
            return 900.0 // 15 minutes
        }
    }
    
    /// Check if location updates should be paused
    public func shouldPauseLocationUpdates() -> Bool {
        switch optimizationLevel {
        case .performance, .balanced:
            return false
        case .batterySaver:
            return batteryLevel < 0.2 // Below 20%
        case .extreme:
            return batteryLevel < 0.5 // Below 50%
        }
    }
    
    /// Get optimized distance filter for location updates
    public func getOptimizedDistanceFilter() -> CLLocationDistance {
        switch optimizationLevel {
        case .performance:
            return 10.0 // 10 meters
        case .balanced:
            return 50.0 // 50 meters
        case .batterySaver:
            return 100.0 // 100 meters
        case .extreme:
            return 500.0 // 500 meters
        }
    }
    
    /// Check if background location updates should be enabled
    public func shouldEnableBackgroundLocationUpdates() -> Bool {
        switch optimizationLevel {
        case .performance, .balanced:
            return true
        case .batterySaver:
            return batteryLevel > 0.3 // Above 30%
        case .extreme:
            return false
        }
    }
    
    /// Get recommended location update strategy
    public func getLocationUpdateStrategy() -> LocationUpdateStrategy {
        if isLowPowerModeEnabled {
            return .minimal
        }
        
        switch optimizationLevel {
        case .performance:
            return .continuous
        case .balanced:
            return .adaptive
        case .batterySaver:
            return .onDemand
        case .extreme:
            return .minimal
        }
    }
    
    /// Apply battery optimizations to location manager
    public func applyOptimizations(to locationManager: CLLocationManager) {
        locationManager.desiredAccuracy = getOptimizedLocationAccuracy()
        locationManager.distanceFilter = getOptimizedDistanceFilter()
        
        // Configure activity type for better power management
        locationManager.activityType = .other
        
        // Pause location updates automatically when possible
        locationManager.pausesLocationUpdatesAutomatically = shouldPauseLocationUpdates()
        
        print("🔋 Applied battery optimizations: \(optimizationLevel.displayName)")
    }
    
    /// Schedule intelligent location updates
    public func scheduleIntelligentLocationUpdate(callback: @escaping () -> Void) {
        locationUpdateTimer?.invalidate()
        
        let interval = getOptimizedUpdateInterval()
        
        locationUpdateTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            // Only update if conditions are favorable
            if self.shouldPerformLocationUpdate() {
                callback()
                self.lastLocationUpdate = Date()
            }
        }
        
        print("📍 Scheduled location updates every \(interval) seconds")
    }
    
    /// Stop intelligent location updates
    public func stopIntelligentLocationUpdates() {
        locationUpdateTimer?.invalidate()
        locationUpdateTimer = nil
        print("📍 Stopped intelligent location updates")
    }
    
    /// Get battery optimization recommendations
    public func getBatteryOptimizationRecommendations() -> [BatteryRecommendation] {
        var recommendations: [BatteryRecommendation] = []
        
        if batteryLevel < 0.2 {
            recommendations.append(.enableLowPowerMode)
            recommendations.append(.reduceLocationAccuracy)
            recommendations.append(.pauseBackgroundUpdates)
        } else if batteryLevel < 0.5 {
            recommendations.append(.useBalancedMode)
            recommendations.append(.increaseUpdateInterval)
        }
        
        if isLowPowerModeEnabled {
            recommendations.append(.minimizeLocationUsage)
        }
        
        return recommendations
    }
    
    // MARK: - Private Methods
    
    private func setupBatteryMonitoring() {
        device.isBatteryMonitoringEnabled = true
        
        // Monitor battery level changes
        NotificationCenter.default.publisher(for: UIDevice.batteryLevelDidChangeNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateBatteryInfo()
                }
            }
            .store(in: &cancellables)
        
        // Monitor battery state changes
        NotificationCenter.default.publisher(for: UIDevice.batteryStateDidChangeNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateBatteryInfo()
                }
            }
            .store(in: &cancellables)
        
        updateBatteryInfo()
    }
    
    private func setupLowPowerModeObserver() {
        NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateLowPowerModeState()
                }
            }
            .store(in: &cancellables)
        
        updateLowPowerModeState()
    }
    
    private func updateBatteryInfo() {
        batteryLevel = device.batteryLevel
        batteryState = device.batteryState
        
        determineOptimizationLevel()
        
        print("🔋 Battery updated: \(Int(batteryLevel * 100))% (\(batteryState.displayName))")
    }
    
    private func updateLowPowerModeState() {
        isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        
        if isLowPowerModeEnabled {
            optimizationLevel = .extreme
        } else {
            determineOptimizationLevel()
        }
        
        print("🔋 Low Power Mode: \(isLowPowerModeEnabled ? "Enabled" : "Disabled")")
    }
    
    private func determineOptimizationLevel() {
        if isLowPowerModeEnabled {
            optimizationLevel = .extreme
        } else if batteryLevel < 0.15 {
            optimizationLevel = .extreme
        } else if batteryLevel < 0.3 {
            optimizationLevel = .batterySaver
        } else if batteryLevel < 0.7 {
            optimizationLevel = .balanced
        } else {
            optimizationLevel = .performance
        }
    }
    
    func shouldPerformLocationUpdate(userOverride: Bool = false) -> Bool {
        // User override bypasses all battery optimization
        if userOverride {
            return true
        }
        
        // Don't update too frequently
        let timeSinceLastUpdate = Date().timeIntervalSince(lastLocationUpdate)
        let minInterval = getOptimizedUpdateInterval() * 0.8 // 80% of interval
        
        if timeSinceLastUpdate < minInterval {
            return false
        }
        
        // Don't update if battery is critically low (below 5%)
        if batteryLevel < 0.05 {
            return false
        }
        
        // Allow location updates when charging, even in extreme mode
        if batteryState == .charging || batteryState == .full {
            return true
        }
        
        // Don't update if in extreme optimization mode and not charging
        if optimizationLevel == .extreme {
            return false
        }
        
        return true
    }
    
}

// MARK: - Optimization Level

public enum OptimizationLevel: String, CaseIterable {
    case performance = "performance"
    case balanced = "balanced"
    case batterySaver = "battery_saver"
    case extreme = "extreme"
    
    public var displayName: String {
        switch self {
        case .performance:
            return "Performance"
        case .balanced:
            return "Balanced"
        case .batterySaver:
            return "Battery Saver"
        case .extreme:
            return "Extreme Battery Saver"
        }
    }
    
    public var description: String {
        switch self {
        case .performance:
            return "Best accuracy and frequent updates"
        case .balanced:
            return "Good accuracy with moderate battery usage"
        case .batterySaver:
            return "Reduced accuracy to save battery"
        case .extreme:
            return "Minimal location usage for maximum battery life"
        }
    }
}

// MARK: - Location Update Strategy

public enum LocationUpdateStrategy: String, CaseIterable {
    case continuous = "continuous"
    case adaptive = "adaptive"
    case onDemand = "on_demand"
    case minimal = "minimal"
    
    public var displayName: String {
        switch self {
        case .continuous:
            return "Continuous"
        case .adaptive:
            return "Adaptive"
        case .onDemand:
            return "On Demand"
        case .minimal:
            return "Minimal"
        }
    }
}

// MARK: - Battery Recommendation

public enum BatteryRecommendation: String, CaseIterable {
    case enableLowPowerMode = "enable_low_power_mode"
    case reduceLocationAccuracy = "reduce_location_accuracy"
    case pauseBackgroundUpdates = "pause_background_updates"
    case useBalancedMode = "use_balanced_mode"
    case increaseUpdateInterval = "increase_update_interval"
    case minimizeLocationUsage = "minimize_location_usage"
    
    public var displayName: String {
        switch self {
        case .enableLowPowerMode:
            return "Enable Low Power Mode"
        case .reduceLocationAccuracy:
            return "Reduce Location Accuracy"
        case .pauseBackgroundUpdates:
            return "Pause Background Updates"
        case .useBalancedMode:
            return "Use Balanced Mode"
        case .increaseUpdateInterval:
            return "Increase Update Interval"
        case .minimizeLocationUsage:
            return "Minimize Location Usage"
        }
    }
    
    public var description: String {
        switch self {
        case .enableLowPowerMode:
            return "Enable system-wide low power mode to extend battery life"
        case .reduceLocationAccuracy:
            return "Use lower accuracy location services to save battery"
        case .pauseBackgroundUpdates:
            return "Pause location updates when app is in background"
        case .useBalancedMode:
            return "Switch to balanced optimization for better battery life"
        case .increaseUpdateInterval:
            return "Update location less frequently to save battery"
        case .minimizeLocationUsage:
            return "Only use location services when absolutely necessary"
        }
    }
}

// MARK: - Extensions

public extension UIDevice.BatteryState {
    var displayName: String {
        switch self {
        case .unknown:
            return "Unknown"
        case .unplugged:
            return "Unplugged"
        case .charging:
            return "Charging"
        case .full:
            return "Full"
        @unknown default:
            return "Unknown"
        }
    }
}
