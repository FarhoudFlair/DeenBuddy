import SwiftUI

/// Welcome screen - first screen in onboarding flow
public struct WelcomeScreen: View {
    let onContinue: () -> Void
    
    public init(onContinue: @escaping () -> Void) {
        self.onContinue = onContinue
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // App icon and branding
            VStack(spacing: 24) {
                // App icon placeholder
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [ColorPalette.primary, ColorPalette.secondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.white)
                }
                
                // App name and tagline
                VStack(spacing: 12) {
                    Text("DeenBuddy")
                        .displayMedium()
                        .foregroundColor(ColorPalette.textPrimary)
                        .fontWeight(.bold)
                    
                    Text("Your companion for daily worship")
                        .titleMedium()
                        .foregroundColor(ColorPalette.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            Spacer()
            
            // Features overview
            VStack(spacing: 20) {
                FeatureRow(
                    icon: "clock.fill",
                    title: "Prayer Times",
                    description: "Accurate prayer times based on your location"
                )
                
                FeatureRow(
                    icon: "location.fill",
                    title: "Qibla Direction",
                    description: "Find the direction to Kaaba from anywhere"
                )
                
                FeatureRow(
                    icon: "book.fill",
                    title: "Prayer Guides",
                    description: "Step-by-step guides for each prayer"
                )
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Continue button
            VStack(spacing: 16) {
                CustomButton.primary("Get Started") {
                    onContinue()
                }
                
                Text("Free • No account required")
                    .labelMedium()
                    .foregroundColor(ColorPalette.textTertiary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(ColorPalette.backgroundPrimary)
    }
}

/// Feature row component for welcome screen
private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(ColorPalette.primary.opacity(0.1))
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(ColorPalette.primary)
            }
            
            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .titleMedium()
                    .foregroundColor(ColorPalette.textPrimary)
                
                Text(description)
                    .bodyMedium()
                    .foregroundColor(ColorPalette.textSecondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview("Welcome Screen") {
    WelcomeScreen {
        print("Continue tapped")
    }
}
