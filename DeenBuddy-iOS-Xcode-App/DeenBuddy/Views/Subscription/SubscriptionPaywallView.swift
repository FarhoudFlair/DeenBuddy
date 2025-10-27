import SwiftUI

/// Main subscription paywall screen
public struct SubscriptionPaywallView: View {
    
    @StateObject private var viewModel: SubscriptionViewModel
    @Environment(\.dismiss) private var dismiss

    // MARK: - Constants

    private enum Constants {
        static let termsURL = URL(string: "https://deenbuddy.com/terms")
        static let privacyURL = URL(string: "https://deenbuddy.com/privacy")
    }

    public init(coordinator: AppCoordinator) {
        self._viewModel = StateObject(
            wrappedValue: SubscriptionViewModel(
                subscriptionService: coordinator.subscriptionService
            )
        )
    }
    
    public var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 32) {
                    headerSection
                    
                    benefitsSection
                    
                    productCardsSection
                    
                    purchaseButton
                    
                    legalSection
                }
                .padding()
            }
            
            if viewModel.isLoading {
                loadingOverlay
            }
        }
        .overlay(alignment: .topTrailing) {
            dismissButton
        }
        .task {
            await viewModel.loadProducts()
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .alert("Success!", isPresented: $viewModel.showSuccessMessage) {
            Button("Continue") {
                dismiss()
            }
        } message: {
            Text("Welcome to DeenBuddy Premium!")
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "crown.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Unlock Premium")
                .font(.system(size: 32, weight: .bold))
            
            Text("Get the most out of DeenBuddy")
                .font(.system(size: 18))
                .foregroundColor(.secondary)
        }
        .padding(.top, 40)
    }
    
    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Premium Features")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(viewModel.benefits, id: \.self) { feature in
                HStack(spacing: 12) {
                    Image(systemName: feature.icon)
                        .font(.title3)
                        .foregroundColor(.orange)
                        .frame(width: 30)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(feature.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(feature.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
    
    private var productCardsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose Your Plan")
                .font(.headline)
                .padding(.horizontal)

            productContent
        }
    }
    
    private var purchaseButton: some View {
        Button {
            Task {
                let success = await viewModel.purchase()
                if success {
                    // Dismiss handled by success alert
                }
            }
        } label: {
            Text("Subscribe Now")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.orange)
                .cornerRadius(12)
        }
        .disabled(viewModel.selectedProduct == nil || viewModel.isLoading || viewModel.availablePlans.isEmpty)
    }
    
    private var legalSection: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    await viewModel.restore()
                }
            } label: {
                Text("Restore Purchases")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            .disabled(viewModel.isLoading)
            
            HStack(spacing: 8) {
                if let termsURL = Constants.termsURL {
                    Link("Terms of Use", destination: termsURL)
                } else {
                    Text("Terms of Use")
                }

                Text("•")

                if let privacyURL = Constants.privacyURL {
                    Link("Privacy Policy", destination: privacyURL)
                } else {
                    Text("Privacy Policy")
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            Text("Subscriptions auto-renew unless cancelled 24 hours before renewal.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.bottom)
    }

    private var dismissButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.title2)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
        }
    }

    @ViewBuilder
    private var productContent: some View {
        switch viewModel.loadingState {
        case .idle, .loading:
            loadingPlansView
        case .loaded:
            plansScrollView
        case .empty(let message):
            stateMessageView(
                systemImage: "cart.badge.questionmark",
                message: message
            )
        case .failed(let message):
            VStack(spacing: 12) {
                stateMessageView(
                    systemImage: "exclamationmark.triangle",
                    message: message
                )

                Button {
                    Task { await viewModel.loadProducts() }
                } label: {
                    Text("Try Again")
                        .font(.subheadline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(10)
                }
                .disabled(viewModel.isLoading)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var plansScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                ForEach(viewModel.availablePlans) { product in
                    SubscriptionProductCard(
                        product: product,
                        isSelected: viewModel.selectedProduct?.id == product.id,
                        onTap: {
                            viewModel.selectProduct(product)
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
        .transition(.opacity)
    }

    private var loadingPlansView: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Loading plans...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .transition(.opacity)
    }

    private func stateMessageView(systemImage: String, message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundColor(.orange)
                .frame(width: 30)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 20)
        .padding(.horizontal)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .transition(.opacity)
    }
}
