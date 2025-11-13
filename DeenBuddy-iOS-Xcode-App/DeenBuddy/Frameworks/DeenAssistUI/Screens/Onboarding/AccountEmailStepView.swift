import SwiftUI

/// Final onboarding step for collecting email and creating account
public struct AccountEmailStepView: View {
    @Binding var email: String
    @Binding var password: String
    @Binding var usePassword: Bool
    @Binding var isSigningIn: Bool
    @Binding var signInError: String?
    @Binding var emailLinkSent: Bool
    
    let userAccountService: any UserAccountServiceProtocol
    let onSignInSuccess: () -> Void
    let onSkip: () -> Void

    @State private var isEmailValid = false
    @State private var isPasswordValid = false

    public init(
        email: Binding<String>,
        password: Binding<String>,
        usePassword: Binding<Bool>,
        isSigningIn: Binding<Bool>,
        signInError: Binding<String?>,
        emailLinkSent: Binding<Bool>,
        userAccountService: any UserAccountServiceProtocol,
        onSignInSuccess: @escaping () -> Void,
        onSkip: @escaping () -> Void
    ) {
        self._email = email
        self._password = password
        self._usePassword = usePassword
        self._isSigningIn = isSigningIn
        self._signInError = signInError
        self._emailLinkSent = emailLinkSent
        self.userAccountService = userAccountService
        self.onSignInSuccess = onSignInSuccess
        self.onSkip = onSkip
    }
    
    public var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "envelope.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(ColorPalette.primary)
                
                Text("Create Your Account")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(ColorPalette.textPrimary)
                
                Text("Save your settings and access them from any device")
                    .font(.body)
                    .foregroundColor(ColorPalette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top, 40)
            
            if emailLinkSent {
                // Email link sent state
                emailLinkSentView
            } else {
                // Email input form
                emailInputForm
            }
            
            Spacer()

            // Skip option
            Button(action: {
                onSkip()
            }) {
                Text("Skip for now")
                    .font(.subheadline)
                    .foregroundColor(ColorPalette.textSecondary)
            }
            .padding(.bottom, 20)
        }
        .padding()
        .onChange(of: email) { _ in
            validateEmail()
        }
        .onChange(of: password) { _ in
            validatePassword()
        }
    }
    
    // MARK: - Email Link Sent View
    
    @ViewBuilder
    private var emailLinkSentView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.green)
            
            Text("Check Your Email")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("We sent a sign-in link to:")
                .font(.body)
                .foregroundColor(ColorPalette.textSecondary)
            
            Text(email)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(ColorPalette.primary)
            
            Text("Tap the link in the email to complete your account setup")
                .font(.caption)
                .foregroundColor(ColorPalette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ColorPalette.surfaceSecondary)
        )
    }
    
    // MARK: - Email Input Form
    
    @ViewBuilder
    private var emailInputForm: some View {
        VStack(spacing: 16) {
            // Email field
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(ColorPalette.textPrimary)
                
                TextField("your@email.com", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .disabled(isSigningIn)
            }
            
            // Password field (conditional)
            if usePassword {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Password")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(ColorPalette.textPrimary)
                    
                    SecureField("At least 6 characters", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(isSigningIn)
                    
                    if !password.isEmpty && !isPasswordValid {
                        Text("Password must be at least 6 characters")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            
            // Error message
            if let error = signInError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
            
            // Primary CTA
            Button(action: handlePrimaryAction) {
                HStack {
                    if isSigningIn {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(usePassword ? "Create Account" : "Send Sign-In Link")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(canProceed ? ColorPalette.primary : Color.gray)
                )
                .foregroundColor(.white)
            }
            .disabled(!canProceed || isSigningIn)
            
            // Toggle password mode
            Button(action: {
                usePassword.toggle()
                password = ""
                signInError = nil
            }) {
                Text(usePassword ? "Use email link instead" : "Use password instead")
                    .font(.subheadline)
                    .foregroundColor(ColorPalette.primary)
            }
            .disabled(isSigningIn)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ColorPalette.surface)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
    
    // MARK: - Computed Properties
    
    private var canProceed: Bool {
        if usePassword {
            return isEmailValid && isPasswordValid
        } else {
            return isEmailValid
        }
    }
    
    // MARK: - Actions
    
    private func handlePrimaryAction() {
        signInError = nil
        isSigningIn = true
        
        Task {
            do {
                if usePassword {
                    // Create account with password
                    try await userAccountService.createUser(email: email, password: password)
                    await MainActor.run {
                        isSigningIn = false
                        onSignInSuccess()
                    }
                } else {
                    // Send email link
                    try await userAccountService.sendSignInLink(to: email)
                    await MainActor.run {
                        isSigningIn = false
                        emailLinkSent = true
                    }
                }
            } catch let error as AccountServiceError {
                await MainActor.run {
                    isSigningIn = false
                    signInError = error.errorDescription
                }
            } catch {
                await MainActor.run {
                    isSigningIn = false
                    signInError = error.localizedDescription
                }
            }
        }
    }
    
    private func validateEmail() {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        isEmailValid = emailPredicate.evaluate(with: email)
    }
    
    private func validatePassword() {
        isPasswordValid = password.count >= 6
    }
}

