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
    /// Temporary flag to surface beta messaging for free premium access.
    /// Flip to false when premium paywall should charge again.
    public var isBetaPremiumFree: Bool { true }
    
    // MARK: - Private Properties
    
    private let subscriptionService: any SubscriptionServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init(subscriptionService: any SubscriptionServiceProtocol) {
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
    
    /// Display benefits for the paywall
    public var includedBenefits: [PaywallBenefit] { Self.includedBenefitsData }
    public var comingSoonBenefits: [PaywallBenefit] { Self.comingSoonBenefitsData }
    /// Legacy accessor retained for compatibility; returns current included benefits.
    public var benefits: [PaywallBenefit] { includedBenefits }
    
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

// MARK: - Paywall Benefit Model

public struct PaywallBenefit: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let description: String
    public let icon: String
    public let isComingSoon: Bool

    public init(id: String = UUID().uuidString, title: String, description: String, icon: String, isComingSoon: Bool = false) {
        self.id = id
        self.title = title
        self.description = description
        self.icon = icon
        self.isComingSoon = isComingSoon
    }
}

// MARK: - Static Benefit Definitions

private extension SubscriptionViewModel {
    static let includedBenefitsData: [PaywallBenefit] = [
        .init(
            title: "Quran Pro Search & Explorer",
            description: "Find ayahs by surah/ayah, themes, or semantic meaning; filter by juz/surah and jump back instantly.",
            icon: "books.vertical.fill"
        ),
        .init(
            title: "Premium Analytics & Insights",
            description: "Daily/weekly/monthly trends, on-time vs late patterns, streak health, and personalized reminders.",
            icon: "chart.bar.xaxis"
        ),
        .init(
            title: "Custom Dhikr Routines",
            description: "Build and save adhkar sets with goals, haptic/sound feedback, and quick-start shortcuts.",
            icon: "sparkles"
        ),
        .init(
            title: "Extended Islamic Calendar",
            description: "See future prayer times and key dates up to the full lookahead. Free tier is capped at 30 days.",
            icon: "calendar.badge.clock"
        )
    ]

    static let comingSoonBenefitsData: [PaywallBenefit] = [
        .init(
            title: "Premium Community Status",
            description: "Share milestones and encouragement when social launches.",
            icon: "person.3.fill",
            isComingSoon: true
        ),
        .init(
            title: "DeenBuddy AI Assistant",
            description: "Context-aware guidance, dua/Quran lookups, and personalized practice tips.",
            icon: "brain.head.profile",
            isComingSoon: true
        ),
        .init(
            title: "Advanced Analytics",
            description: "Deeper trends like heatmaps, weekday patterns, variability, and gentle habit suggestions.",
            icon: "waveform.path.ecg",
            isComingSoon: true
        ),
        .init(
            title: "Early Access to Beta Features",
            description: "Try new tools first and help shape what ships.",
            icon: "rocket.fill",
            isComingSoon: true
        ),
        .init(
            title: "Many More to Come",
            description: "We’ll keep expanding with user-requested features.",
            icon: "ellipsis.circle",
            isComingSoon: true
        )
    ]
}
