import XCTest
@testable import DeenBuddy

@MainActor
final class SubscriptionServiceTests: XCTestCase {
    
    var sut: MockSubscriptionService!
    
    override func setUp() {
        super.setUp()
        sut = MockSubscriptionService()
    }
    
    override func tearDown() {
        // Reset shared subscription status to avoid leaking state across tests
        SubscriptionStatusManager.shared.updateStatus(.free)
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Product Loading Tests
    
    func testLoadProductsSuccess() async throws {
        // When: Loading products
        try await sut.loadProducts()
        
        // Then: Products should be loaded
        XCTAssertTrue(sut.loadProductsCalled, "loadProducts should be called")
        XCTAssertEqual(sut.availableProducts.count, 3, "Should load 3 products")
        
        // Verify product order
        XCTAssertEqual(sut.availableProducts[0].period, .weekly)
        XCTAssertEqual(sut.availableProducts[1].period, .monthly)
        XCTAssertEqual(sut.availableProducts[2].period, .yearly)
    }
    
    func testLoadProductsFailure() async {
        // Given: Service configured to fail
        sut.shouldFailLoad = true
        
        // When/Then: Loading products should throw error
        do {
            try await sut.loadProducts()
            XCTFail("Should throw error")
        } catch let error as SubscriptionError {
            if case .productLoadFailed = error {
                XCTAssertTrue(true, "Correct error thrown")
            } else {
                XCTFail("Wrong error type")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    // MARK: - Purchase Tests
    
    func testPurchaseSuccess() async throws {
        // Given: A product to purchase
        let product = SubscriptionProduct.mockMonthly
        
        // When: Purchasing the product
        let success = try await sut.purchase(product)
        
        // Then: Purchase should succeed
        XCTAssertTrue(success, "Purchase should succeed")
        XCTAssertTrue(sut.purchaseCalled, "purchase should be called")
        XCTAssertEqual(sut.lastPurchasedProduct?.id, product.id)
        XCTAssertTrue(sut.subscriptionStatus.isPremium, "User should have premium status")
    }
    
    func testPurchaseFailure() async {
        // Given: Service configured to fail
        sut.shouldFailPurchase = true
        let product = SubscriptionProduct.mockMonthly
        
        // When/Then: Purchase should throw error
        do {
            _ = try await sut.purchase(product)
            XCTFail("Should throw error")
        } catch let error as SubscriptionError {
            if case .purchaseFailed = error {
                XCTAssertTrue(true, "Correct error thrown")
            } else {
                XCTFail("Wrong error type")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    func testPurchaseUserCancelled() async throws {
        // Given: User will cancel purchase
        sut.shouldReturnUserCancelled = true
        let product = SubscriptionProduct.mockMonthly
        
        // When: User cancels purchase
        let success = try await sut.purchase(product)
        
        // Then: Purchase should return false
        XCTAssertFalse(success, "Purchase should return false when cancelled")
        XCTAssertFalse(sut.subscriptionStatus.isPremium, "User should not have premium")
    }
    
    func testPurchasePending() async {
        // Given: Purchase will be pending
        sut.shouldReturnPending = true
        let product = SubscriptionProduct.mockMonthly
        
        // When/Then: Purchase should throw pending error
        do {
            _ = try await sut.purchase(product)
            XCTFail("Should throw pending error")
        } catch let error as SubscriptionError {
            if case .pendingApproval = error {
                XCTAssertTrue(true, "Correct error thrown")
            } else {
                XCTFail("Wrong error type")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    // MARK: - Restore Purchases Tests
    
    func testRestorePurchasesSuccess() async throws {
        // When: Restoring purchases
        try await sut.restorePurchases()
        
        // Then: Restore should be called
        XCTAssertTrue(sut.restoreCalled, "restorePurchases should be called")
    }
    
    func testRestorePurchasesFailure() async {
        // Given: Service configured to fail
        sut.shouldFailRestore = true
        
        // When/Then: Restore should throw error
        do {
            try await sut.restorePurchases()
            XCTFail("Should throw error")
        } catch let error as SubscriptionError {
            if case .restoreFailed = error {
                XCTAssertTrue(true, "Correct error thrown")
            } else {
                XCTFail("Wrong error type")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    // MARK: - Entitlement Tests
    
    func testCheckEntitlementFreeUser() {
        // Given: Free user
        sut.subscriptionStatus = .free
        
        // When: Checking entitlement
        let hasAccess = sut.checkEntitlement(for: .advancedPrayerTracking)
        
        // Then: Should not have access
        XCTAssertFalse(hasAccess, "Free user should not have premium features")
        XCTAssertTrue(sut.checkEntitlementCalled)
    }
    
    func testCheckEntitlementPremiumUser() {
        // Given: Premium user
        sut.subscriptionStatus = .premium
        
        // When: Checking entitlement
        let hasAccess = sut.checkEntitlement(for: .advancedPrayerTracking)
        
        // Then: Should have access
        XCTAssertTrue(hasAccess, "Premium user should have premium features")
    }
    
    func testCheckEntitlementExpiredSubscription() {
        // Given: Expired subscription
        sut.simulateExpiredSubscription()
        
        // When: Checking entitlement
        let hasAccess = sut.checkEntitlement(for: .advancedPrayerTracking)
        
        // Then: Should not have access
        XCTAssertFalse(hasAccess, "Expired subscription should not have access")
    }
    
    // MARK: - Status Tests
    
    func testRefreshStatus() async throws {
        // When: Refreshing status
        try await sut.refreshStatus()
        
        // Then: Refresh should be called
        XCTAssertTrue(sut.refreshStatusCalled)
    }
    
    func testSubscriptionStatusCaching() {
        // Given: Premium status
        let manager = SubscriptionStatusManager.shared
        manager.updateStatus(.premium)
        
        // When: Checking status
        let isPremium = manager.isPremium
        
        // Then: Should be premium
        XCTAssertTrue(isPremium)
        XCTAssertEqual(manager.tier, .premium)
    }
    
    // MARK: - Transaction Observer Tests
    
    func testStartObservingTransactions() {
        // When: Starting observer
        sut.startObservingTransactions()
        
        // Then: Observer should be started
        XCTAssertTrue(sut.startObservingCalled)
    }
    
    func testStopObservingTransactions() {
        // When: Stopping observer
        sut.stopObservingTransactions()
        
        // Then: Observer should be stopped
        XCTAssertTrue(sut.stopObservingCalled)
    }
    
    // MARK: - Subscription Status Tests
    
    func testSubscriptionStatusExpiration() {
        // Given: Subscription expiring in 5 days
        let expirationDate = Date().addingTimeInterval(5 * 24 * 60 * 60)
        let status = SubscriptionStatus(
            tier: .premium,
            isActive: true,
            productId: "yearly_premium_sub",
            expirationDate: expirationDate,
            willAutoRenew: false
        )
        
        // Then: Should be expiring soon
        XCTAssertTrue(status.isExpiringSoon)
        XCTAssertEqual(status.daysUntilExpiration, 5)
        XCTAssertFalse(status.isExpired)
    }
    
    func testSubscriptionStatusExpired() {
        // Given: Expired subscription
        let expirationDate = Date().addingTimeInterval(-86400) // Yesterday
        let status = SubscriptionStatus(
            tier: .premium,
            isActive: false,
            productId: "yearly_premium_sub",
            expirationDate: expirationDate,
            willAutoRenew: false
        )
        
        // Then: Should be expired
        XCTAssertTrue(status.isExpired)
        XCTAssertFalse(status.isExpiringSoon)
        XCTAssertFalse(status.isPremium)
    }
    
    func testSubscriptionStatusGracePeriod() {
        // Given: Subscription in grace period
        let status = SubscriptionStatus(
            tier: .premium,
            isActive: true,
            productId: "yearly_premium_sub",
            expirationDate: Date().addingTimeInterval(-3600), // Past expiration
            isInGracePeriod: true,
            willAutoRenew: true
        )
        
        // Then: Should still have premium access
        XCTAssertTrue(status.isPremium)
        XCTAssertFalse(status.isExpired) // Grace period prevents expiration
        XCTAssertTrue(status.isInGracePeriod)
    }
}

