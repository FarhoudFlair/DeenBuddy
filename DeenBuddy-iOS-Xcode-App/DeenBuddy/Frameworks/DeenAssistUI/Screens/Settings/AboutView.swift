import SwiftUI

/// About view with app information
public struct AboutView: View {
    let onDismiss: () -> Void
    
    public init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // App icon and info
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [ColorPalette.primary, ColorPalette.secondary],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100, height: 100)
                            
                            Image(systemName: "moon.stars.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                        }
                        
                        VStack(spacing: 8) {
                            Text("DeenBuddy")
                                .headlineLarge()
                                .foregroundColor(ColorPalette.textPrimary)
                            
                            Text("Version \(appVersion)")
                                .titleMedium()
                                .foregroundColor(ColorPalette.textSecondary)
                            
                            Text("Your companion for daily worship")
                                .bodyMedium()
                                .foregroundColor(ColorPalette.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    
                    // Description
                    VStack(alignment: .leading, spacing: 16) {
                        Text("About")
                            .headlineSmall()
                            .foregroundColor(ColorPalette.textPrimary)
                        
                        Text("DeenBuddy is designed to help Muslims maintain their daily prayers with accurate prayer times, Qibla direction, and comprehensive prayer guides. The app works offline and respects your privacy.")
                            .bodyMedium()
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                    
                    // Features
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Features")
                            .headlineSmall()
                            .foregroundColor(ColorPalette.textPrimary)
                        
                        VStack(spacing: 12) {
                            FeatureItem(
                                icon: "clock.fill",
                                title: "Accurate Prayer Times",
                                description: "Multiple calculation methods supported"
                            )
                            
                            FeatureItem(
                                icon: "safari.fill",
                                title: "Qibla Compass",
                                description: "Find direction to Kaaba from anywhere"
                            )
                            
                            FeatureItem(
                                icon: "book.fill",
                                title: "Prayer Guides",
                                description: "Step-by-step guides for Sunni and Shia prayers"
                            )
                            
                            FeatureItem(
                                icon: "bell.fill",
                                title: "Prayer Reminders",
                                description: "Customizable notifications"
                            )
                            
                            FeatureItem(
                                icon: "wifi.slash",
                                title: "Offline Support",
                                description: "Works without internet connection"
                            )
                        }
                    }
                    
                    // Acknowledgments
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Acknowledgments")
                            .headlineSmall()
                            .foregroundColor(ColorPalette.textPrimary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("• AdhanSwift library for prayer time calculations")
                                .bodySmall()
                                .foregroundColor(ColorPalette.textSecondary)
                            Text("• AlAdhan API for additional prayer time data")
                                .bodySmall()
                                .foregroundColor(ColorPalette.textSecondary)
                            Text("• Islamic scholars for prayer guide content review")
                                .bodySmall()
                                .foregroundColor(ColorPalette.textSecondary)
                        }
                    }
                    
                    // Contact
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Contact")
                            .headlineSmall()
                            .foregroundColor(ColorPalette.textPrimary)
                        
                        Text("For support, feedback, or suggestions, please contact us through the App Store or visit our website.")
                            .bodyMedium()
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                    
                    // Copyright
                    Text("© 2025 DeenBuddy. All rights reserved.")
                        .labelSmall()
                        .foregroundColor(ColorPalette.textTertiary)
                        .padding(.top, 16)
                }
                .padding(24)
            }
            .background(ColorPalette.backgroundPrimary)
            .navigationTitle("About")
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
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
}

/// Feature item component
private struct FeatureItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(ColorPalette.primary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .labelLarge()
                    .foregroundColor(ColorPalette.textPrimary)
                
                Text(description)
                    .bodySmall()
                    .foregroundColor(ColorPalette.textSecondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview("About View") {
    AboutView {
        print("Dismiss")
    }
}
