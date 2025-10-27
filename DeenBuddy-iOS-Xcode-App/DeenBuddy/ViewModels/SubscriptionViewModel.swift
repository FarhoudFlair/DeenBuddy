import Foundation
import SwiftUI
import Combine

/// Describes the loading lifecycle for subscription plans shown on the paywall.
public enum SubscriptionLoadingState {
    case idle
    case loading
    case loaded
    case empty(message: String)
    case failed(message: String)

    var message: String? {
        switch self {
        case .empty(let message), .failed(let message):
            return message
        case .idle, .loading, .loaded:
            return nil
        }
    }
}

/// View model for subscription paywall and management
@MainActor
public class SubscriptionViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var selectedProduct: SubscriptionProduct?
    @Published public var isLoading = false
    @Published public var showError = false
    @Published public var errorMessage = ""
    @Published public var availablePlans: [SubscriptionProduct] = []
    @Published public var loadingState: SubscriptionLoadingState = .idle
    @Published public var showSuccessMessage = false
    
    // MARK: - Private Properties
    
    private let subscriptionService: SubscriptionServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init(subscriptionService: SubscriptionServiceProtocol) {
        self.subscriptionService = subscriptionService
        observeService()
    }
    
    // MARK: - Public Methods
    
    /// Load available subscription products
    public func loadProducts() async {
        loadingState = .loading
        isLoading = true
        showError = false
        defer { isLoading = false }
        do {
            let plans = try await subscriptionService.fetchAvailablePlans()
            availablePlans = plans

            if let popularPlan = plans.first(where: { $0.isPopular }) ?? plans.first {
                selectedProduct = popularPlan
            } else {
                selectedProduct = nil
            }

            loadingState = plans.isEmpty
                ? .empty(message: "No plans are currently available. Please check again soon.")
                : .loaded
        } catch {
            handleError(error)
            availablePlans = []
            selectedProduct = nil
            loadingState = .failed(message: errorMessage)
            // showError is already set to true by handleError(error)
        }
    }
    
    /// Purchase the selected subscription
    public func purchase() async -> Bool {
        guard let product = selectedProduct else {
            errorMessage = "Please select a subscription plan"
            showError = true
            return false
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let success = try await subscriptionService.purchase(product)
            
            if success {
                showSuccessMessage = true
                // Auto-reset success message after short delay
                Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    await MainActor.run { self?.showSuccessMessage = false }
                }
            }
            
            return success
        } catch {
            handleError(error)
            return false
        }
    }
    
    /// Restore previous purchases
    public func restore() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await subscriptionService.restorePurchases()
            showSuccessMessage = true
            // Auto-reset success message after short delay
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run { self?.showSuccessMessage = false }
            }
        } catch {
            handleError(error)
        }
    }
    
    /// Select a specific product
    public func selectProduct(_ product: SubscriptionProduct) {
        selectedProduct = product
    }
    
    /// Get display benefits for the paywall
    public var benefits: [PremiumFeature] {
        PremiumFeature.allCases
    }
    
    // MARK: - Private Methods
    
    private func observeService() {
        // Removed concrete SubscriptionService publisher observation to preserve protocol abstraction
        // State is managed manually via loadProducts(), purchase(), and restore()
    }
    
    private func handleError(_ error: Error) {
        if let subscriptionError = error as? SubscriptionError {
            errorMessage = subscriptionError.localizedDescription
        } else {
            errorMessage = error.localizedDescription
        }
        showError = true
    }
}
