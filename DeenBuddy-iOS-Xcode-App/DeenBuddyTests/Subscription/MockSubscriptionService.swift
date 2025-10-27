import Foundation
import Combine
@testable import DeenBuddy

/// Mock subscription service for testing
@MainActor
class MockSubscriptionService: ObservableObject, SubscriptionServiceProtocol {
    
    // MARK: - Published Properties
    
    @Published var subscriptionStatus: SubscriptionStatus = .free
    @Published var availableProducts: [SubscriptionProduct] = []
    @Published var isLoading: Bool = false
    @Published var error: Error? = nil
    
    // MARK: - Test Flags
    
    var shouldFailLoad = false
    var shouldFailPurchase = false
    var shouldFailRestore = false
    var shouldReturnUserCancelled = false
    var shouldReturnPending = false
    
    // MARK: - Test Counters
    
    var loadProductsCalled = false
    var purchaseCalled = false
    var restoreCalled = false
    var checkEntitlementCalled = false
    var refreshStatusCalled = false
    var startObservingCalled = false
    var stopObservingCalled = false
    
    var lastPurchasedProduct: SubscriptionProduct?

    // MARK: - Mock Methods
    
    func loadProducts() async throws {
        loadProductsCalled = true
        
        if shouldFailLoad {
            throw SubscriptionError.productLoadFailed(NSError(domain: "test", code: -1))
        }
        
        availableProducts = [
            .mockWeekly,
            .mockMonthly,
            .mockYearly
        ]
    }
    
    func purchase(_ product: SubscriptionProduct) async throws -> Bool {
        purchaseCalled = true
        lastPurchasedProduct = product
        
        if shouldFailPurchase {
            throw SubscriptionError.purchaseFailed(NSError(domain: "test", code: -1))
        }
        
        if shouldReturnUserCancelled {
            return false
        }
        
        if shouldReturnPending {
            throw SubscriptionError.pendingApproval
        }
        
        // Simulate successful purchase
        subscriptionStatus = .premium
        return true
    }
    
    func restorePurchases() async throws {
        restoreCalled = true
        
        if shouldFailRestore {
            throw SubscriptionError.restoreFailed(NSError(domain: "test", code: -1))
        }
    }
    
    func checkEntitlement(for feature: PremiumFeature) -> Bool {
        checkEntitlementCalled = true
        return subscriptionStatus.isPremium
    }
    
    func refreshStatus() async throws {
        refreshStatusCalled = true
    }
    
    func startObservingTransactions() {
        startObservingCalled = true
    }
    
    func stopObservingTransactions() {
        stopObservingCalled = true
    }
    
    // MARK: - Test Helpers
    
    func reset() {
        subscriptionStatus = .free
        availableProducts = []
        isLoading = false
        error = nil
        
        shouldFailLoad = false
        shouldFailPurchase = false
        shouldFailRestore = false
        shouldReturnUserCancelled = false
        shouldReturnPending = false
        
        loadProductsCalled = false
        purchaseCalled = false
        restoreCalled = false
        checkEntitlementCalled = false
        refreshStatusCalled = false
        startObservingCalled = false
        stopObservingCalled = false
        
        lastPurchasedProduct = nil
    }
    
    func simulatePremiumUser() {
        subscriptionStatus = .premium
    }
    
    func simulateExpiredSubscription() {
        subscriptionStatus = SubscriptionStatus(
            tier: .premium,
            isActive: false,
            productId: "yearly_premium_sub",
            expirationDate: Date().addingTimeInterval(-86400), // Expired yesterday
            willAutoRenew: false
        )
    }
}

// MARK: - Mock Data

extension SubscriptionProduct {
    static let mockWeekly = SubscriptionProduct(
        id: "weekly_premium_sub",
        displayName: "Weekly Premium",
        description: "Test weekly subscription",
        price: Decimal(2.99),
        priceFormatted: "$2.99",
        period: .weekly,
        product: nil,
        savings: nil,
        isPopular: false
    )
    
    static let mockMonthly = SubscriptionProduct(
        id: "monthly_premium_sub",
        displayName: "Monthly Premium",
        description: "Test monthly subscription",
        price: Decimal(9.99),
        priceFormatted: "$9.99",
        period: .monthly,
        product: nil,
        savings: nil,
        isPopular: false
    )
    
    static let mockYearly = SubscriptionProduct(
        id: "yearly_premium_sub",
        displayName: "Yearly Premium",
        description: "Test yearly subscription",
        price: Decimal(39.99),
        priceFormatted: "$39.99",
        period: .yearly,
        product: nil,
        savings: "Save 40%",
        isPopular: true
    )
}

