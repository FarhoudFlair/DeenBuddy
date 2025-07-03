import SwiftUI
import DeenAssistProtocols

/// Privacy policy and consent management screen
public struct PrivacyScreen: View {
    let onDismiss: () -> Void
    
    @State private var hasAcceptedPrivacyPolicy = false
    @State private var hasAcceptedLocationConsent = false
    @State private var hasAcceptedNotificationConsent = false
    @State private var showingFullPrivacyPolicy = false
    
    public init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Privacy & Data Protection")
                            .headlineLarge()
                            .foregroundColor(ColorPalette.textPrimary)
                        
                        Text("Your privacy is important to us. Please review how we handle your data.")
                            .bodyMedium()
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                    
                    // Data collection summary
                    dataCollectionSummary
                    
                    // Consent sections
                    consentSections
                    
                    // Privacy policy link
                    privacyPolicySection
                    
                    // Action buttons
                    actionButtons
                }
                .padding()
            }
            .navigationTitle("Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingFullPrivacyPolicy) {
            FullPrivacyPolicyView {
                showingFullPrivacyPolicy = false
            }
        }
    }
    
    @ViewBuilder
    private var dataCollectionSummary: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Data We Collect")
                .headlineMedium()
                .foregroundColor(ColorPalette.textPrimary)
            
            VStack(spacing: 12) {
                DataCollectionItem(
                    icon: "location.fill",
                    title: "Location Data",
                    description: "Used to calculate accurate prayer times and Qibla direction",
                    isRequired: true
                )
                
                DataCollectionItem(
                    icon: "bell.fill",
                    title: "Notification Preferences",
                    description: "Stored locally to schedule prayer reminders",
                    isRequired: false
                )
                
                DataCollectionItem(
                    icon: "gear",
                    title: "App Settings",
                    description: "Prayer calculation method, madhab, and theme preferences",
                    isRequired: false
                )
                
                DataCollectionItem(
                    icon: "chart.bar.fill",
                    title: "Usage Analytics",
                    description: "Anonymous usage data to improve the app experience",
                    isRequired: false
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorPalette.surface)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
    
    @ViewBuilder
    private var consentSections: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Consent")
                .headlineMedium()
                .foregroundColor(ColorPalette.textPrimary)
            
            VStack(spacing: 16) {
                ConsentToggle(
                    title: "Location Services",
                    description: "Allow the app to access your location for prayer times and Qibla direction",
                    isOn: $hasAcceptedLocationConsent,
                    isRequired: true
                )
                
                ConsentToggle(
                    title: "Push Notifications",
                    description: "Receive prayer time reminders and important updates",
                    isOn: $hasAcceptedNotificationConsent,
                    isRequired: false
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorPalette.surface)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
    
    @ViewBuilder
    private var privacyPolicySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Privacy Policy")
                .headlineMedium()
                .foregroundColor(ColorPalette.textPrimary)
            
            Button(action: {
                showingFullPrivacyPolicy = true
            }) {
                HStack {
                    Text("Read Full Privacy Policy")
                        .bodyMedium()
                        .foregroundColor(ColorPalette.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(ColorPalette.primary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(ColorPalette.primary, lineWidth: 1)
                )
            }
            
            Toggle(isOn: $hasAcceptedPrivacyPolicy) {
                Text("I have read and accept the Privacy Policy")
                    .bodyMedium()
                    .foregroundColor(ColorPalette.textPrimary)
            }
            .toggleStyle(SwitchToggleStyle(tint: ColorPalette.primary))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorPalette.surface)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: 12) {
            CustomButton.primary("Save Preferences") {
                savePrivacyPreferences()
                onDismiss()
            }
            .disabled(!hasAcceptedPrivacyPolicy)
            
            CustomButton.secondary("Manage Data") {
                // Open data management options
            }
        }
    }
    
    private func savePrivacyPreferences() {
        let preferences = PrivacyPreferences(
            hasAcceptedPrivacyPolicy: hasAcceptedPrivacyPolicy,
            hasAcceptedLocationConsent: hasAcceptedLocationConsent,
            hasAcceptedNotificationConsent: hasAcceptedNotificationConsent,
            consentDate: Date()
        )
        
        PrivacyManager.shared.savePreferences(preferences)
    }
}

// MARK: - Supporting Views

private struct DataCollectionItem: View {
    let icon: String
    let title: String
    let description: String
    let isRequired: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(ColorPalette.primary)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .bodyMedium()
                        .fontWeight(.medium)
                        .foregroundColor(ColorPalette.textPrimary)
                    
                    if isRequired {
                        Text("Required")
                            .captionSmall()
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(ColorPalette.accent.opacity(0.2))
                            )
                            .foregroundColor(ColorPalette.accent)
                    }
                }
                
                Text(description)
                    .bodySmall()
                    .foregroundColor(ColorPalette.textSecondary)
            }
            
            Spacer()
        }
    }
}

private struct ConsentToggle: View {
    let title: String
    let description: String
    @Binding var isOn: Bool
    let isRequired: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .bodyMedium()
                            .fontWeight(.medium)
                            .foregroundColor(ColorPalette.textPrimary)
                        
                        if isRequired {
                            Text("Required")
                                .captionSmall()
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(ColorPalette.accent.opacity(0.2))
                                )
                                .foregroundColor(ColorPalette.accent)
                        }
                    }
                    
                    Text(description)
                        .bodySmall()
                        .foregroundColor(ColorPalette.textSecondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $isOn)
                    .toggleStyle(SwitchToggleStyle(tint: ColorPalette.primary))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(ColorPalette.border, lineWidth: 1)
        )
    }
}

// MARK: - Full Privacy Policy View

private struct FullPrivacyPolicyView: View {
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(privacyPolicyText)
                        .bodyMedium()
                        .foregroundColor(ColorPalette.textPrimary)
                }
                .padding()
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
    }
    
    private var privacyPolicyText: String {
        return """
        # Privacy Policy for Deen Assist
        
        Last updated: \(DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .none))
        
        ## Introduction
        
        Deen Assist ("we", "our", or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, and safeguard your information when you use our mobile application.
        
        ## Information We Collect
        
        ### Location Data
        We collect your device's location to:
        - Calculate accurate prayer times for your location
        - Determine the Qibla direction
        - Provide location-based Islamic content
        
        Location data is processed locally on your device and is not transmitted to our servers unless you explicitly consent to cloud sync features.
        
        ### Usage Data
        We may collect anonymous usage statistics to improve the app, including:
        - App features used
        - Crash reports
        - Performance metrics
        
        ### Settings and Preferences
        We store your app preferences locally, including:
        - Prayer calculation method
        - Madhab selection
        - Notification preferences
        - Theme settings
        
        ## How We Use Your Information
        
        We use the collected information to:
        - Provide accurate prayer times and Qibla direction
        - Send prayer reminders (if enabled)
        - Improve app functionality and user experience
        - Provide customer support
        
        ## Data Sharing
        
        We do not sell, trade, or otherwise transfer your personal information to third parties, except:
        - With your explicit consent
        - To comply with legal obligations
        - To protect our rights and safety
        
        ## Data Security
        
        We implement appropriate security measures to protect your information:
        - Local data encryption
        - Secure API communications
        - Regular security updates
        
        ## Your Rights
        
        You have the right to:
        - Access your personal data
        - Correct inaccurate data
        - Delete your data
        - Withdraw consent
        - Data portability
        
        ## Children's Privacy
        
        Our app is suitable for all ages. We do not knowingly collect personal information from children under 13 without parental consent.
        
        ## Changes to This Policy
        
        We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy in the app.
        
        ## Contact Us
        
        If you have any questions about this Privacy Policy, please contact us at:
        Email: privacy@deenassist.app
        
        This policy is effective as of the date listed above.
        """
    }
}

// MARK: - Privacy Manager

public class PrivacyManager {
    public static let shared = PrivacyManager()
    
    private let userDefaults = UserDefaults.standard
    private let preferencesKey = "DeenAssist.PrivacyPreferences"
    
    private init() {}
    
    public func savePreferences(_ preferences: PrivacyPreferences) {
        if let data = try? JSONEncoder().encode(preferences) {
            userDefaults.set(data, forKey: preferencesKey)
            print("Privacy preferences saved")
        }
    }
    
    public func loadPreferences() -> PrivacyPreferences? {
        guard let data = userDefaults.data(forKey: preferencesKey),
              let preferences = try? JSONDecoder().decode(PrivacyPreferences.self, from: data) else {
            return nil
        }
        return preferences
    }
    
    public func hasAcceptedPrivacyPolicy() -> Bool {
        return loadPreferences()?.hasAcceptedPrivacyPolicy ?? false
    }
    
    public func hasLocationConsent() -> Bool {
        return loadPreferences()?.hasAcceptedLocationConsent ?? false
    }
    
    public func hasNotificationConsent() -> Bool {
        return loadPreferences()?.hasAcceptedNotificationConsent ?? false
    }
}

// MARK: - Privacy Models

public struct PrivacyPreferences: Codable {
    public let hasAcceptedPrivacyPolicy: Bool
    public let hasAcceptedLocationConsent: Bool
    public let hasAcceptedNotificationConsent: Bool
    public let consentDate: Date
    
    public init(
        hasAcceptedPrivacyPolicy: Bool,
        hasAcceptedLocationConsent: Bool,
        hasAcceptedNotificationConsent: Bool,
        consentDate: Date
    ) {
        self.hasAcceptedPrivacyPolicy = hasAcceptedPrivacyPolicy
        self.hasAcceptedLocationConsent = hasAcceptedLocationConsent
        self.hasAcceptedNotificationConsent = hasAcceptedNotificationConsent
        self.consentDate = consentDate
    }
}
