import Foundation
import Network
import Combine

/// Network connectivity monitoring service
@MainActor
public class NetworkMonitor: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var isConnected = true
    @Published public var connectionType: ConnectionType = .unknown
    @Published public var isExpensive = false
    @Published public var isConstrained = false
    
    // MARK: - Private Properties
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Singleton
    
    public static let shared = NetworkMonitor()
    
    private init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Start network monitoring
    public func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.updateNetworkStatus(path)
            }
        }
        
        monitor.start(queue: queue)
    }
    
    /// Stop network monitoring
    public func stopMonitoring() {
        monitor.cancel()
    }
    
    /// Check if a specific host is reachable
    public func checkReachability(to host: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            let hostMonitor = NWPathMonitor()
            
            hostMonitor.pathUpdateHandler = { path in
                continuation.resume(returning: path.status == .satisfied)
                hostMonitor.cancel()
            }
            
            hostMonitor.start(queue: queue)
            
            // Timeout after 5 seconds
            DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                continuation.resume(returning: false)
                hostMonitor.cancel()
            }
        }
    }
    
    /// Wait for network connection to be available
    public func waitForConnection(timeout: TimeInterval = 30) async -> Bool {
        if isConnected {
            return true
        }
        
        return await withCheckedContinuation { continuation in
            var hasResumed = false
            
            // Subscribe to connection changes
            let cancellable = $isConnected
                .filter { $0 }
                .first()
                .sink { _ in
                    if !hasResumed {
                        hasResumed = true
                        continuation.resume(returning: true)
                    }
                }
            
            // Timeout
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                if !hasResumed {
                    hasResumed = true
                    cancellable.cancel()
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    /// Get network quality information
    public var networkQuality: NetworkQuality {
        if !isConnected {
            return .none
        }
        
        if isConstrained {
            return .poor
        }
        
        switch connectionType {
        case .wifi:
            return .excellent
        case .cellular:
            return isExpensive ? .fair : .good
        case .ethernet:
            return .excellent
        case .unknown:
            return .fair
        }
    }
    
    // MARK: - Private Methods
    
    private func updateNetworkStatus(_ path: NWPath) {
        isConnected = path.status == .satisfied
        isExpensive = path.isExpensive
        isConstrained = path.isConstrained
        
        // Determine connection type
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
        } else {
            connectionType = .unknown
        }
        
        // Log network changes
        print("🌐 Network status changed: \(isConnected ? "Connected" : "Disconnected") (\(connectionType.displayName))")
        
        // Post notification for other services
        NotificationCenter.default.post(
            name: .networkStatusChanged,
            object: nil,
            userInfo: [
                "isConnected": isConnected,
                "connectionType": connectionType,
                "isExpensive": isExpensive,
                "isConstrained": isConstrained
            ]
        )
    }
}

// MARK: - Connection Type

public enum ConnectionType: String, CaseIterable {
    case wifi = "wifi"
    case cellular = "cellular"
    case ethernet = "ethernet"
    case unknown = "unknown"
    
    public var displayName: String {
        switch self {
        case .wifi:
            return "Wi-Fi"
        case .cellular:
            return "Cellular"
        case .ethernet:
            return "Ethernet"
        case .unknown:
            return "Unknown"
        }
    }
    
    public var icon: String {
        switch self {
        case .wifi:
            return "wifi"
        case .cellular:
            return "antenna.radiowaves.left.and.right"
        case .ethernet:
            return "cable.connector"
        case .unknown:
            return "questionmark.circle"
        }
    }
}

// MARK: - Network Quality

public enum NetworkQuality: String, CaseIterable {
    case none = "none"
    case poor = "poor"
    case fair = "fair"
    case good = "good"
    case excellent = "excellent"
    
    public var displayName: String {
        return rawValue.capitalized
    }
    
    public var color: String {
        switch self {
        case .none:
            return "gray"
        case .poor:
            return "red"
        case .fair:
            return "orange"
        case .good:
            return "yellow"
        case .excellent:
            return "green"
        }
    }
    
    /// Recommended timeout for network requests based on quality
    public var recommendedTimeout: TimeInterval {
        switch self {
        case .none:
            return 5.0
        case .poor:
            return 30.0
        case .fair:
            return 20.0
        case .good:
            return 15.0
        case .excellent:
            return 10.0
        }
    }
    
    /// Whether to use high quality content based on network
    public var shouldUseHighQuality: Bool {
        switch self {
        case .none, .poor:
            return false
        case .fair, .good, .excellent:
            return true
        }
    }
}

// MARK: - Offline Manager

@MainActor
public class OfflineManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var isOfflineMode = false
    @Published public var offlineCapabilities: [OfflineCapability] = []
    
    // MARK: - Private Properties
    
    private let networkMonitor = NetworkMonitor.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Singleton
    
    public static let shared = OfflineManager()
    
    private init() {
        setupNetworkObserver()
        setupOfflineCapabilities()
    }
    
    // MARK: - Public Methods
    
    /// Enable offline mode manually
    public func enableOfflineMode() {
        isOfflineMode = true
        print("📱 Offline mode enabled")
    }
    
    /// Disable offline mode manually
    public func disableOfflineMode() {
        isOfflineMode = false
        print("📱 Offline mode disabled")
    }
    
    /// Check if a feature is available offline
    public func isAvailableOffline(_ feature: OfflineCapability) -> Bool {
        return offlineCapabilities.contains(feature)
    }
    
    /// Get offline status message
    public var offlineStatusMessage: String {
        if networkMonitor.isConnected && !isOfflineMode {
            return "Online"
        } else if isOfflineMode {
            return "Offline Mode"
        } else {
            return "No Internet Connection"
        }
    }
    
    // MARK: - Private Methods
    
    private func setupNetworkObserver() {
        networkMonitor.$isConnected
            .sink { [weak self] isConnected in
                if !isConnected {
                    self?.enableOfflineMode()
                } else {
                    // Don't automatically disable offline mode when connection returns
                    // Let user decide or implement smart logic
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupOfflineCapabilities() {
        offlineCapabilities = [
            .prayerTimes,
            .qiblaDirection,
            .prayerGuides,
            .settings,
            .basicContent
        ]
    }
}

// MARK: - Offline Capability

public enum OfflineCapability: String, CaseIterable {
    case prayerTimes = "prayer_times"
    case qiblaDirection = "qibla_direction"
    case prayerGuides = "prayer_guides"
    case settings = "settings"
    case basicContent = "basic_content"
    case notifications = "notifications"
    
    public var displayName: String {
        switch self {
        case .prayerTimes:
            return "Prayer Times"
        case .qiblaDirection:
            return "Qibla Direction"
        case .prayerGuides:
            return "Prayer Guides"
        case .settings:
            return "Settings"
        case .basicContent:
            return "Basic Content"
        case .notifications:
            return "Notifications"
        }
    }
    
    public var description: String {
        switch self {
        case .prayerTimes:
            return "Calculate prayer times using cached location"
        case .qiblaDirection:
            return "Show Qibla direction using device compass"
        case .prayerGuides:
            return "Access downloaded prayer guides"
        case .settings:
            return "Modify app settings and preferences"
        case .basicContent:
            return "View cached Islamic content"
        case .notifications:
            return "Receive prayer time notifications"
        }
    }
}

// MARK: - Notification Extensions

public extension Notification.Name {
    static let networkStatusChanged = Notification.Name("networkStatusChanged")
    static let offlineModeChanged = Notification.Name("offlineModeChanged")
}
