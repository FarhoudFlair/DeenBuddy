import Foundation
import StoreKit
import Combine

/// StoreKit 2 subscription service implementation
@MainActor
public class SubscriptionService: BaseService, SubscriptionServiceProtocol {
    
    // MARK: - Published Properties
    
    @Published public private(set) var subscriptionStatus: SubscriptionStatus = .free
    @Published public private(set) var availableProducts: [SubscriptionProduct] = []
    
    // MARK: - Private Properties
    
    private let productIds = [
        "yearly_premium_sub",
        "monthly_premium_sub",
        "weekly_premium_sub"
    ]

    private var transactionTask: Task<Void, Never>?
    private var isObserving = false
    private let performanceMonitor: PerformanceMonitor
    
    // MARK: - Initialization
    
    public init(performanceMonitor: PerformanceMonitor = .shared) {
        self.performanceMonitor = performanceMonitor
        super.init(serviceName: "SubscriptionService")
        
        // Load cached status
        loadCachedStatus()
    }
    
    deinit {
        transactionTask?.cancel()
        transactionTask = nil
        isObserving = false
    }
    
    // MARK: - Public Methods
    
    public func loadProducts() async throws {
        let operationName = "SubscriptionService.loadProducts"
        performanceMonitor.startTiming(operation: operationName)
        defer { performanceMonitor.endTiming(operation: operationName) }
        
        isLoading = true
        error = nil

        defer { isLoading = false }

        do {
            logger.info("Loading subscription products...")
            
            let storeProducts = try await Product.products(for: productIds)

            guard storeProducts.isEmpty == false else {
                let emptyError = SubscriptionConfigurationError.productsUnavailable
                logger.error("❌ StoreKit returned no subscription products")
                let wrappedError = SubscriptionError.productLoadFailed(emptyError)
                self.error = wrappedError
                throw wrappedError
            }
            
            logger.info("Loaded \(storeProducts.count) products from StoreKit")
            
            // Map StoreKit products to domain models
            let mappedProducts = storeProducts.compactMap { product in
                mapProductToDomain(product)
            }
            
            // Calculate savings for yearly products based on monthly pricing
            availableProducts = mappedProducts.map { product in
                if product.period == .yearly {
                    let calculatedSavings = calculateSavings(for: product, allProducts: mappedProducts)
                    return SubscriptionProduct(
                        id: product.id,
                        displayName: product.displayName,
                        description: product.description,
                        price: product.price,
                        priceFormatted: product.priceFormatted,
                        period: product.period,
                        product: product.product,
                        savings: calculatedSavings,
                        isPopular: product.isPopular
                    )
                }
                return product
            }
            .sorted { $0.period.sortOrder < $1.period.sortOrder }
            
            logger.info("✅ Successfully loaded \(self.availableProducts.count) subscription products")
            
        } catch let subscriptionError as SubscriptionError {
            logger.error("❌ Failed to load products: \(subscriptionError.localizedDescription)")
            self.error = subscriptionError
            throw subscriptionError
        } catch {
            logger.error("❌ Failed to load products: \(error.localizedDescription)")
            let wrappedError = SubscriptionError.productLoadFailed(error)
            self.error = wrappedError
            throw wrappedError
        }
    }
    
    public func purchase(_ subscriptionProduct: SubscriptionProduct) async throws -> Bool {
        guard let product = subscriptionProduct.product else {
            throw SubscriptionError.productUnavailable
        }

        let operationName = "SubscriptionService.purchase"
        performanceMonitor.startTiming(operation: operationName)
        defer { performanceMonitor.endTiming(operation: operationName) }

        isLoading = true
        error = nil

        defer { isLoading = false }

        do {
            logger.info("Initiating purchase for \(product.id)...")
            
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                
                logger.info("✅ Purchase successful for \(transaction.productID)")
                
                // Finish the transaction
                await transaction.finish()
                
                // Refresh status to update entitlements
                do {
                    try await refreshStatus()
                } catch {
                    logger.error("⚠️ Failed to refresh status after purchase, but transaction was successful: \(error.localizedDescription)")
                    // Continue to update status manager and notify even if refresh fails
                }
                
                // Notify status manager (always run after transaction finishes)
                SubscriptionStatusManager.shared.updateStatus(subscriptionStatus)
                
                // Post notification for UI updates (always run after transaction finishes)
                NotificationCenter.default.post(
                    name: .subscriptionStatusChanged,
                    object: nil
                )
                
                lastSuccessfulOperation = Date()
                return true
                
            case .userCancelled:
                logger.info("User cancelled purchase")
                return false
                
            case .pending:
                logger.info("Purchase pending approval")
                throw SubscriptionError.pendingApproval
                
            @unknown default:
                logger.error("Unknown purchase result")
                throw SubscriptionError.unknownResult
            }
            
        } catch let error as SubscriptionError {
            logger.error("❌ Purchase failed: \(error.localizedDescription)")
            self.error = error
            throw error
        } catch {
            logger.error("❌ Purchase failed: \(error.localizedDescription)")
            let subscriptionError = SubscriptionError.purchaseFailed(error)
            self.error = subscriptionError
            throw subscriptionError
        }
    }
    
    public func restorePurchases() async throws {
        let operationName = "SubscriptionService.restorePurchases"
        performanceMonitor.startTiming(operation: operationName)
        defer { performanceMonitor.endTiming(operation: operationName) }

        isLoading = true
        error = nil

        defer { isLoading = false }

        do {
            logger.info("Restoring purchases...")
            
            try await AppStore.sync()
            try await refreshStatus()
            
            logger.info("✅ Purchases restored successfully")
            
            lastSuccessfulOperation = Date()
            
        } catch {
            logger.error("❌ Failed to restore purchases: \(error.localizedDescription)")
            let subscriptionError = SubscriptionError.restoreFailed(error)
            self.error = subscriptionError
            throw subscriptionError
        }
    }
    
    public func checkEntitlement(for feature: PremiumFeature) -> Bool {
        return subscriptionStatus.isPremium
    }
    
    public func refreshStatus() async throws {
        let operationName = "SubscriptionService.refreshStatus"
        performanceMonitor.startTiming(operation: operationName)
        defer { performanceMonitor.endTiming(operation: operationName) }

        logger.info("Refreshing subscription status...")

        var currentSubscription: SubscriptionStatus = .free
        
        // Check current entitlements
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                if transaction.productType == .autoRenewable {
                    logger.info("Found active subscription: \(transaction.productID)")
                    currentSubscription = await determineStatus(from: transaction)
                    break
                }
            } catch {
                logger.error("Failed to verify transaction: \(error.localizedDescription)")
            }
        }
        
        subscriptionStatus = currentSubscription
        
        // Cache the status
        cacheStatus(currentSubscription)
        
        // Update status manager
        SubscriptionStatusManager.shared.updateStatus(currentSubscription)
        
        logger.info("✅ Subscription status refreshed: \(currentSubscription.statusDescription)")
    }
    
    public func startObservingTransactions() {
        guard !isObserving else { return }
        
        logger.info("Starting transaction observer...")
        
        isObserving = true
        
        transactionTask = Task.detached { [weak self] in
            for await verificationResult in Transaction.updates {
                guard let self = self else { return }

                do {
                    let transaction = try self.checkVerified(verificationResult)

                    // Log transaction update (Logger is thread-safe)
                    self.logger.info("Transaction update received: \(transaction.productID)")

                    // Handle transaction update (async, already @MainActor)
                    await self.handleTransactionUpdate(transaction)

                    await transaction.finish()
                } catch {
                    // Log error (Logger is thread-safe)
                    self.logger.error("Transaction verification failed: \(error.localizedDescription)")
                }
            }
        }
        
        logger.info("✅ Transaction observer started")
    }
    
    public func stopObservingTransactions() {
        guard isObserving else { return }
        
        logger.info("Stopping transaction observer...")
        
        transactionTask?.cancel()
        transactionTask = nil
        isObserving = false
        
        logger.info("✅ Transaction observer stopped")
    }
    
    // MARK: - Private Methods
    
    private func handleTransactionUpdate(_ transaction: Transaction) async {
        do {
            try await refreshStatus()

            NotificationCenter.default.post(
                name: .subscriptionStatusChanged,
                object: nil
            )
        } catch {
            logger.error(
                "Failed to refresh status after transaction update for product \(transaction.productID): \(error.localizedDescription)"
            )
        }
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw SubscriptionError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
    
    private func determineStatus(from transaction: Transaction) async -> SubscriptionStatus {
        // Get subscription status information
        let statusInfo = try? await transaction.subscriptionStatus
        
        let renewalState = statusInfo?.state
        let willAutoRenew = renewalState == .subscribed ||
            renewalState == .inGracePeriod ||
            renewalState == .inBillingRetryPeriod

        return SubscriptionStatus(
            tier: .premium,
            isActive: true,
            productId: transaction.productID,
            expirationDate: transaction.expirationDate,
            renewalDate: transaction.expirationDate,
            isInGracePeriod: statusInfo?.state == .inGracePeriod,
            isInBillingRetry: statusInfo?.state == .inBillingRetryPeriod,
            willAutoRenew: willAutoRenew
        )
    }
    
    private func mapProductToDomain(_ product: Product) -> SubscriptionProduct? {
        do {
            let period = try determinePeriod(from: product.id)
            
            return SubscriptionProduct(
                id: product.id,
                displayName: product.displayName,
                description: product.description,
                price: product.price,
                priceFormatted: product.displayPrice,
                period: period,
                product: product,
                savings: nil, // Calculated later for yearly products
                isPopular: product.id == "yearly_premium_sub"
            )
        } catch {
            logger.warning("⚠️ Skipping unrecognized product ID: \(product.id) - \(error.localizedDescription)")
            return nil
        }
    }
    
    private func determinePeriod(from productId: String) throws -> SubscriptionPeriod {
        if productId.contains("weekly") {
            return .weekly
        } else if productId.contains("monthly") {
            return .monthly
        } else if productId.contains("yearly") {
            return .yearly
        }
        
        // Fail loudly instead of silent default
        throw SubscriptionError.unrecognizedProductId(productId)
    }
    
    private func calculateSavings(for yearlyProduct: SubscriptionProduct, allProducts: [SubscriptionProduct]) -> String? {
        // Only calculate savings for yearly subscriptions
        guard yearlyProduct.period == .yearly else { return nil }
        
        // Find the monthly product to compare pricing
        guard let monthlyProduct = allProducts.first(where: { $0.period == .monthly }) else {
            logger.warning("⚠️ Cannot calculate savings: monthly product not found")
            return nil
        }
        
        // Get prices as Decimal for accurate calculation
        let yearlyCost = yearlyProduct.price
        let monthlyCost = monthlyProduct.price
        
        // Avoid division by zero
        guard monthlyCost > 0 else {
            logger.warning("⚠️ Cannot calculate savings: monthly price is zero")
            return nil
        }
        
        // Calculate annual cost if paying monthly: monthlyCost * 12
        let annualCostIfMonthly = monthlyCost * 12
        
        // Avoid invalid scenarios
        guard annualCostIfMonthly > yearlyCost else {
            logger.warning("⚠️ Cannot calculate savings: yearly cost (\(yearlyCost)) is not less than annual monthly cost (\(annualCostIfMonthly))")
            return nil
        }
        
        // Calculate savings percentage: (1 - yearlyCost / annualCostIfMonthly) * 100
        let savingsRatio = 1 - (yearlyCost / annualCostIfMonthly)
        let savingsPercent = savingsRatio * 100

        // Round to nearest integer (convert Decimal to Double for rounding)
        let roundedPercent = Int((savingsPercent as NSDecimalNumber).doubleValue.rounded())
        
        // Validate reasonable range (1-99%)
        guard roundedPercent > 0 && roundedPercent < 100 else {
            logger.warning("⚠️ Calculated savings percentage (\(roundedPercent)%) is outside valid range")
            return nil
        }
        
        return "Save \(roundedPercent)%"
    }
    
    private func loadCachedStatus() {
        if let data = UserDefaults.standard.data(forKey: "subscription_status_cache"),
           let status = try? JSONDecoder().decode(SubscriptionStatus.self, from: data) {
            subscriptionStatus = status
            logger.info("Loaded cached subscription status: \(status.statusDescription)")
        }
    }
    
    private func cacheStatus(_ status: SubscriptionStatus) {
        if let data = try? JSONEncoder().encode(status) {
            UserDefaults.standard.set(data, forKey: "subscription_status_cache")
            logger.info("Cached subscription status")
        }
    }
}

// MARK: - Subscription Error

public enum SubscriptionError: LocalizedError {
    case productUnavailable
    case productLoadFailed(Error)
    case verificationFailed
    case purchaseFailed(Error)
    case restoreFailed(Error)
    case pendingApproval
    case unknownResult
    case unrecognizedProductId(String)
    
    public var errorDescription: String? {
        switch self {
        case .productUnavailable:
            return "The selected subscription is currently unavailable."
        case .productLoadFailed(let error):
            return "Failed to load subscriptions: \(error.localizedDescription)"
        case .verificationFailed:
            return "Failed to verify purchase with Apple."
        case .purchaseFailed(let error):
            return "Purchase failed: \(error.localizedDescription)"
        case .restoreFailed(let error):
            return "Failed to restore purchases: \(error.localizedDescription)"
        case .pendingApproval:
            return "Purchase is pending approval. Check back later."
        case .unknownResult:
            return "An unknown error occurred during purchase."
        case .unrecognizedProductId(let productId):
            return "Unrecognized subscription product ID: '\(productId)'. Expected 'weekly', 'monthly', or 'yearly' in product identifier."
        }
    }
}

private enum SubscriptionConfigurationError: LocalizedError {
    case missingProductIdentifiers
    case productsUnavailable

    var errorDescription: String? {
        switch self {
        case .missingProductIdentifiers:
            return "Subscription products are not configured. Please verify Configuration.storekit identifiers."
        case .productsUnavailable:
            return "Subscription products could not be loaded at this time. Please try again later."
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    public static let subscriptionStatusChanged = Notification.Name("subscriptionStatusChanged")
}

// PerformanceMonitor integration actively monitors timing for key operations:
// - loadProducts(): Product loading performance
// - purchase(): Purchase operation performance
// - restorePurchases(): Purchase restoration performance
// - refreshStatus(): Status refresh performance
