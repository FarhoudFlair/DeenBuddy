import Foundation
import Combine

/// Protocol for subscription service operations
@MainActor
public protocol SubscriptionServiceProtocol: ObservableObject {
    /// Current subscription status
    var subscriptionStatus: SubscriptionStatus { get }
    
    /// Available subscription products
    var availableProducts: [SubscriptionProduct] { get }
    
    /// Whether the service is currently loading
    var isLoading: Bool { get }
    
    /// Any error that occurred
    var error: Error? { get }
    
    /// Load available subscription products from StoreKit
    func loadProducts() async throws
    
    /// Purchase a subscription product
    /// - Parameter product: The subscription product to purchase
    /// - Returns: True if purchase succeeded, false if user cancelled
    func purchase(_ product: SubscriptionProduct) async throws -> Bool
    
    /// Restore previous purchases
    func restorePurchases() async throws
    
    /// Check if user has entitlement for a specific feature
    /// - Parameter feature: The premium feature to check
    /// - Returns: True if user has access to the feature
    func checkEntitlement(for feature: PremiumFeature) -> Bool
    
    /// Refresh subscription status from StoreKit
    func refreshStatus() async throws
    
    /// Start observing transaction updates in the background
    func startObservingTransactions()
    
    /// Stop observing transaction updates
    func stopObservingTransactions()
}

/// Convenience defaults for subscription plan fetching.
public extension SubscriptionServiceProtocol {
    func fetchAvailablePlans() async throws -> [SubscriptionProduct] {
        try await loadProducts()
        return availableProducts
    }
}
