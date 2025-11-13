import SwiftUI

/// Account settings screen for managing user account
public struct AccountSettingsScreen: View {
    @Environment(\.dismiss) private var dismiss
    
    private let userAccountService: any UserAccountServiceProtocol
    
    @State private var marketingOptIn: Bool = false
    @State private var previousMarketingOptIn: Bool = false
    @State private var isLoading: Bool = false
    @State private var showingDeleteConfirmation: Bool = false
    @State private var showingSignOutConfirmation: Bool = false
    @State private var errorMessage: String? = nil
    @State private var isProgrammaticMarketingRevert: Bool = false
    
    public init(userAccountService: any UserAccountServiceProtocol) {
        self.userAccountService = userAccountService
    }
    
    public var body: some View {
        NavigationView {
            List {
                // Account info section
                Section {
                    if let user = userAccountService.currentUser {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.title2)
                                .foregroundColor(ColorPalette.primary)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Signed in as")
                                    .font(.caption)
                                    .foregroundColor(ColorPalette.textSecondary)
                                
                                Text(user.email ?? "No email")
                                    .font(.body)
                                    .foregroundColor(ColorPalette.textPrimary)
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        HStack {
                            Image(systemName: "person.circle")
                                .font(.title2)
                                .foregroundColor(ColorPalette.textSecondary)
                            
                            Text("Not signed in")
                                .font(.body)
                                .foregroundColor(ColorPalette.textSecondary)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Account")
                }
                
                // Marketing preferences section
                if userAccountService.currentUser != nil {
                    Section {
                        Toggle(isOn: $marketingOptIn) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Email Marketing")
                                    .font(.body)
                                
                                Text("Receive updates, tips, and special offers")
                                    .font(.caption)
                                    .foregroundColor(ColorPalette.textSecondary)
                            }
                        }
                        .disabled(isLoading)
                        .onChange(of: marketingOptIn) { newValue in
                            // Skip if this is a programmatic revert to prevent recursive updates
                            guard !isProgrammaticMarketingRevert else {
                                return
                            }

                            guard !isLoading else {
                                marketingOptIn = previousMarketingOptIn
                                return
                            }
                            previousMarketingOptIn = newValue
                            errorMessage = nil
                            isLoading = true
                            updateMarketingOptIn(newValue)
                        }
                    } header: {
                        Text("Preferences")
                    } footer: {
                        Text("You can change this at any time. We respect your privacy.")
                            .font(.caption)
                    }
                }
                
                // Account actions section
                if userAccountService.currentUser != nil {
                    Section {
                        Button(action: {
                            showingSignOutConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .foregroundColor(ColorPalette.primary)
                                Text("Sign Out")
                                    .foregroundColor(ColorPalette.textPrimary)
                            }
                        }
                        .disabled(isLoading)
                        
                        Button(role: .destructive, action: {
                            showingDeleteConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Account")
                            }
                        }
                        .disabled(isLoading)
                    } header: {
                        Text("Actions")
                    }
                }
                
                // Error message
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Sign Out", isPresented: $showingSignOutConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    signOut()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Delete Account", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("This will permanently delete your account and all associated data. This action cannot be undone.")
            }
            .overlay {
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                    }
                }
            }
        }
        .onAppear {
            loadMarketingPreference()
        }
    }
    
    // MARK: - Actions
    
    private func loadMarketingPreference() {
        // Load from UserDefaults or PrivacyManager
        let privacyManager = PrivacyManager.shared
        marketingOptIn = privacyManager.hasMarketingConsent() ?? false
        previousMarketingOptIn = marketingOptIn
    }

    private func updateMarketingOptIn(_ enabled: Bool) {
        Task {
            do {
                try await userAccountService.updateMarketingOptIn(enabled)
                
                // Also save locally
                let privacyManager = PrivacyManager.shared
                privacyManager.saveMarketingConsent(enabled)
                
                await MainActor.run {
                    isLoading = false
                    previousMarketingOptIn = enabled
                }
            } catch let error as AccountServiceError {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.errorDescription
                    // Revert toggle programmatically without triggering onChange
                    isProgrammaticMarketingRevert = true
                    marketingOptIn = !enabled
                    previousMarketingOptIn = marketingOptIn
                    isProgrammaticMarketingRevert = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                    // Revert toggle programmatically without triggering onChange
                    isProgrammaticMarketingRevert = true
                    marketingOptIn = !enabled
                    previousMarketingOptIn = marketingOptIn
                    isProgrammaticMarketingRevert = false
                }
            }
        }
    }
    
    private func signOut() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await userAccountService.signOut()
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch let error as AccountServiceError {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.errorDescription
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func deleteAccount() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await userAccountService.deleteAccount()
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch let error as AccountServiceError {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.errorDescription
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Privacy Manager Extension

extension PrivacyManager {
    public func hasMarketingConsent() -> Bool? {
        let key = "DeenBuddy.Privacy.MarketingConsent"
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: key) != nil else {
            return nil
        }
        return defaults.bool(forKey: key)
    }
    
    public func saveMarketingConsent(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "DeenBuddy.Privacy.MarketingConsent")
    }
}
