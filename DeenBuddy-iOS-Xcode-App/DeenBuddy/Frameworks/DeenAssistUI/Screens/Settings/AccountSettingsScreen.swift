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
    @State private var infoMessage: String? = nil
    @State private var isProgrammaticMarketingRevert: Bool = false
    @State private var showingLinkEmailSheet: Bool = false
    @State private var linkEmailAddress: String = ""
    
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
                                Text(NSLocalizedString("AccountSettings.signedInAs", comment: "Label showing user is signed in"))
                                    .font(.caption)
                                    .foregroundColor(ColorPalette.textSecondary)

                                if let email = user.email {
                                    Text(email)
                                        .font(.body)
                                        .foregroundColor(ColorPalette.textPrimary)
                                } else {
                                    Text(NSLocalizedString("AccountSettings.noEmailAssociated", comment: "Message when no email is associated with account"))
                                        .font(.body)
                                        .foregroundColor(ColorPalette.textSecondary)

                                    Button(action: {
                                        showingLinkEmailSheet = true
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "envelope.badge.fill")
                                            Text(NSLocalizedString("AccountSettings.linkEmail", comment: "Button to link email to account"))
                                        }
                                        .font(.subheadline)
                                        .foregroundColor(ColorPalette.primary)
                                    }
                                    .disabled(isLoading)
                                }
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
                            sendPasswordResetEmail()
                        }) {
                            HStack {
                                Image(systemName: "envelope.badge")
                                    .foregroundColor(ColorPalette.primary)
                                Text("Send Password Reset Email")
                                    .foregroundColor(ColorPalette.textPrimary)
                            }
                        }
                        .disabled(isLoading)
                        
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
                
                if let info = infoMessage {
                    Section {
                        Text(info)
                            .font(.caption)
                            .foregroundColor(ColorPalette.primary)
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
            .sheet(isPresented: $showingLinkEmailSheet) {
                LinkEmailSheetView(
                    email: $linkEmailAddress,
                    isLoading: isLoading,
                    onSendLink: { email in
                        sendLinkEmail(to: email)
                    },
                    onCancel: {
                        showingLinkEmailSheet = false
                        linkEmailAddress = ""
                    }
                )
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
    
    private func sendPasswordResetEmail() {
        guard let email = userAccountService.currentUser?.email else {
            errorMessage = "No email address is associated with this account."
            return
        }
        
        isLoading = true
        errorMessage = nil
        infoMessage = nil
        
        Task {
            do {
                try await userAccountService.sendPasswordResetEmail(to: email)
                await MainActor.run {
                    isLoading = false
                    infoMessage = "Password reset email sent to \(email)."
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

    private func sendLinkEmail(to email: String) {
        isLoading = true
        errorMessage = nil
        infoMessage = nil

        Task {
            do {
                try await userAccountService.sendSignInLink(to: email)
                await MainActor.run {
                    isLoading = false
                    showingLinkEmailSheet = false
                    linkEmailAddress = ""
                    infoMessage = String(
                        format: NSLocalizedString("AccountSettings.linkEmailSent", comment: "Confirmation message after sign-in link sent"),
                        email
                    )
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

// MARK: - Link Email Sheet View

private struct LinkEmailSheetView: View {
    @Binding var email: String
    let isLoading: Bool
    let onSendLink: (String) -> Void
    let onCancel: () -> Void

    @State private var validationError: String? = nil

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("AccountSettings.linkEmailDescription", comment: "Description for link email sheet"))
                        .font(.body)
                        .foregroundColor(ColorPalette.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 16)

                VStack(alignment: .leading, spacing: 8) {
                    TextField(
                        NSLocalizedString("AccountSettings.emailPlaceholder", comment: "Email input placeholder"),
                        text: $email
                    )
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .padding()
                    .background(ColorPalette.backgroundSecondary)
                    .cornerRadius(10)
                    .onChange(of: email) { _ in
                        validationError = nil
                    }

                    if let error = validationError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                Button(action: {
                    if validateEmail() {
                        onSendLink(email)
                    }
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text(NSLocalizedString("AccountSettings.sendLinkButton", comment: "Button to send sign-in link"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(email.isEmpty ? ColorPalette.textSecondary : ColorPalette.primary)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(email.isEmpty || isLoading)

                Spacer()
            }
            .padding(.horizontal, 20)
            .navigationTitle(NSLocalizedString("AccountSettings.linkEmail", comment: "Link Email sheet title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("AccountSettings.cancel", comment: "Cancel button")) {
                        onCancel()
                    }
                    .disabled(isLoading)
                }
            }
        }
    }

    private func validateEmail() -> Bool {
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}")
        if !emailPredicate.evaluate(with: email) {
            validationError = NSLocalizedString("AccountSettings.invalidEmailError", comment: "Error shown for invalid email format")
            return false
        }
        return true
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
