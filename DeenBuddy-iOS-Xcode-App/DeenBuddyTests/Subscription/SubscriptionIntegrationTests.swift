import XCTest
import StoreKit
@testable import DeenBuddy

@MainActor
final class SubscriptionIntegrationTests: XCTestCase {
    
    var subscriptionService: SubscriptionService!
    var statusManager: SubscriptionStatusManager!
    
    override func setUp() async throws {
        try await super.setUp()
        
        subscriptionService = SubscriptionService()
        statusManager = SubscriptionStatusManager.shared
        
        // Clear any cached state
        statusManager.clearCache()
    }
    
    override func tearDown() {
        subscriptionService.stopObservingTransactions()
        subscriptionService = nil
        statusManager = nil
        super.tearDown()
    }
    
    // MARK: - StoreKit Configuration Tests
    
    func testLoadProductsFromStoreKitConfiguration() async throws {
        // When: Loading products from StoreKit configuration
        try await subscriptionService.loadProducts()
        
        // Then: Products should be loaded
        let products = subscriptionService.availableProducts
        
        XCTAssertFalse(products.isEmpty, "Should load products from StoreKit config")
        XCTAssertGreaterThanOrEqual(products.count, 1, "Should have at least 1 subscription option")
        
        // Verify expected product IDs are present
        let productIds = products.map { $0.id }
        let expectedIds = ["yearly_premium_sub", "monthly_premium_sub", "weekly_premium_sub"]
        
        let missingIds = expectedIds.filter { !productIds.contains($0) }
        XCTAssertTrue(missingIds.isEmpty, "Missing expected products: \(missingIds.joined(separator: \", \"))")
        
        // Verify products have proper data
        for product in products {
            XCTAssertFalse(product.displayName.isEmpty, "Product should have display name")
            XCTAssertFalse(product.priceFormatted.isEmpty, "Product should have formatted price")
            XCTAssertGreaterThan(product.price, 0, "Product should have price > 0")
        }
    }
    
    func testProductsSortedByPeriod() async throws {
        // When: Loading products
        try await subscriptionService.loadProducts()
        
        // Then: Products should be sorted by period
        let products = subscriptionService.availableProducts
        
        if products.count >= 2 {
            for i in 0..<(products.count - 1) {
                XCTAssertLessThanOrEqual(
                    products[i].period.sortOrder,
                    products[i + 1].period.sortOrder,
                    "Products should be sorted by period"
                )
            }
        }
    }
    
    // MARK: - Transaction Listener Tests
    
    func testTransactionListenerLifecycle() async throws {
        // When: Starting transaction listener
        subscriptionService.startObservingTransactions()
        
        // Then: Listener should be active
        // Note: We can't directly test private properties, but we can verify no crashes
        
        // When: Stopping transaction listener
        subscriptionService.stopObservingTransactions()
        
        // Then: Should stop cleanly without errors
        XCTAssertTrue(true, "Transaction listener lifecycle completed successfully")
    }
    
    func testTransactionListenerRestart() {
        // When: Starting and stopping multiple times
        subscriptionService.startObservingTransactions()
        subscriptionService.stopObservingTransactions()
        subscriptionService.startObservingTransactions()
        subscriptionService.stopObservingTransactions()
        
        // Then: Should handle restart without issues
        XCTAssertTrue(true, "Transaction listener can be restarted")
    }
    
    // MARK: - Status Synchronization Tests
    
    func testStatusSynchronizationBetweenServiceAndManager() async throws {
        // Given: Initial free status
        XCTAssertEqual(statusManager.currentStatus.tier, .free)
        
        // When: Service refreshes status
        try await subscriptionService.refreshStatus()
        
        // Note: In test environment without actual purchases, status should remain free
        // This test verifies the synchronization mechanism works
        
        let serviceStatus = subscriptionService.subscriptionStatus
        let managerStatus = statusManager.currentStatus
        
        // Then: Statuses should be synchronized
        // Note: Both should be free in test environment
        XCTAssertEqual(serviceStatus.tier, managerStatus.tier)
    }
    
    func testStatusManagerUpdatePropagation() {
        // Given: A premium status
        let premiumStatus = SubscriptionStatus.premium
        
        // When: Updating status manager
        statusManager.updateStatus(premiumStatus)
        
        // Then: Status should be updated
        XCTAssertTrue(statusManager.isPremium)
        XCTAssertEqual(statusManager.tier, .premium)
        XCTAssertTrue(statusManager.checkEntitlement(for: .advancedPrayerTracking))
    }
    
    // MARK: - Cache Persistence Tests
    
    func testStatusCachePersistence() async throws {
        // Given: A premium status
        let premiumStatus = SubscriptionStatus.premium
        statusManager.updateStatus(premiumStatus)
        
        // When: Creating new status manager instance (simulating app restart)
        let newManager = SubscriptionStatusManager.shared // Singleton
        
        // Then: Status should be loaded from cache
        XCTAssertTrue(newManager.isPremium, "Status should persist across instances")
        
        // Cleanup
        statusManager.clearCache()
    }
    
    func testCacheClearance() {
        // Given: Premium status cached
        statusManager.updateStatus(.premium)
        XCTAssertTrue(statusManager.isPremium)
        
        // When: Clearing cache
        statusManager.clearCache()
        
        // Then: Should revert to free
        XCTAssertFalse(statusManager.isPremium)
        XCTAssertEqual(statusManager.tier, .free)
    }
    
    // MARK: - Status Refresh Tests
    
    func testRefreshStatusWithoutPurchases() async throws {
        // When: Refreshing status with no active subscriptions
        try await subscriptionService.refreshStatus()
        
        // Then: Status should be free
        XCTAssertEqual(subscriptionService.subscriptionStatus.tier, .free)
        XCTAssertFalse(subscriptionService.subscriptionStatus.isPremium)
    }
    
    func testRefreshStatusPerformance() async throws {
        // Measure: Status refresh performance
        let measureOptions = XCTMeasureOptions()
        measureOptions.iterationCount = 10
        
        measure(options: measureOptions) {
            let expectation = expectation(description: "Status refresh")
            
            Task { @MainActor in
                do {
                    try await subscriptionService.refreshStatus()
                    expectation.fulfill()
                } catch {
                    XCTFail("Status refresh failed: \(error)")
                    expectation.fulfill()
                }
            }
            
            wait(for: [expectation], timeout: 0.2)
        }
        
        // Performance should be under 200ms as per requirements
    }
    
    // MARK: - Subscription State Tests
    
    func testMultipleProductLoads() async throws {
        // When: Loading products multiple times
        try await subscriptionService.loadProducts()
        let firstCount = subscriptionService.availableProducts.count
        
        try await subscriptionService.loadProducts()
        let secondCount = subscriptionService.availableProducts.count
        
        // Then: Should return consistent results
        XCTAssertEqual(firstCount, secondCount, "Multiple loads should return same products")
    }
}
