import Foundation
import Combine

/// Lightweight singleton for quick entitlement checks throughout the app
@MainActor
public class SubscriptionStatusManager: ObservableObject {
    
    public static let shared = SubscriptionStatusManager()
    
    // MARK: - Published Properties
    
    @Published public private(set) var currentStatus: SubscriptionStatus = .free
    
    // MARK: - Private Properties
    
    private let cacheKey = "subscription_status_cache"
    
    // MARK: - Initialization
    
    private init() {
        loadCachedStatus()
    }
    
    // MARK: - Public Methods
    
    /// Check if user has entitlement for a specific premium feature
    /// - Parameter feature: The premium feature to check
    /// - Returns: True if user has access
    public func checkEntitlement(for feature: PremiumFeature) -> Bool {
        guard currentStatus.isPremium else { return false }
        return currentStatus.tier.features.contains(feature)
    }
    
    /// Update the current subscription status
    /// - Parameter status: The new subscription status
    public func updateStatus(_ status: SubscriptionStatus) {
        currentStatus = status
        cacheStatus(status)
    }
    
    /// Check if user has premium subscription
    public var isPremium: Bool {
        currentStatus.isPremium
    }
    
    /// Get the current subscription tier
    public var tier: SubscriptionTier {
        currentStatus.tier
    }
    
    // MARK: - Private Methods
    
    private func loadCachedStatus() {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let status = try? JSONDecoder().decode(SubscriptionStatus.self, from: data) {
            currentStatus = status
        }
    }
    
    private func cacheStatus(_ status: SubscriptionStatus) {
        if let data = try? JSONEncoder().encode(status) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }
    
    /// Clear cached subscription status (useful for testing/logout)
    public func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
        currentStatus = .free
    }
}

