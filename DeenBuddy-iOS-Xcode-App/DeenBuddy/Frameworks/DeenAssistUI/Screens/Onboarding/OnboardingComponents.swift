import SwiftUI

// MARK: - Onboarding Supporting Components

struct OnboardingStepHeader: View {
    let icon: String
    let title: String
    let description: String
    let showLogo: Bool
    
    init(icon: String, title: String, description: String, showLogo: Bool = true) {
        self.icon = icon
        self.title = title
        self.description = description
        self.showLogo = showLogo
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // DeenBuddy logo at the top if enabled
            if showLogo {
                MascotTitleView.navigationTitle(titleText: "DeenBuddy")
                    .padding(.bottom, 8)
            }
            
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(ColorPalette.primary)
                .accessibilityLabel(title + " icon")
            
            VStack(spacing: 8) {
                Text(title)
                    .headlineLarge()
                    .foregroundColor(ColorPalette.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text(description)
                    .bodyMedium()
                    .foregroundColor(ColorPalette.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil) // Allow unlimited lines to prevent truncation
                    .fixedSize(horizontal: false, vertical: true) // Allow vertical expansion
                    .padding(.horizontal)
            }
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(description)")
    }
}

struct OnboardingSelectionCard: View {
    let title: String
    let description: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .bodyMedium()
                        .fontWeight(.medium)
                        .foregroundColor(ColorPalette.textPrimary)
                    
                    Text(description)
                        .bodySmall()
                        .foregroundColor(ColorPalette.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? ColorPalette.primary : ColorPalette.border)
                    .accessibilityLabel(isSelected ? "Selected" : "Not selected")
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ColorPalette.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? ColorPalette.primary : ColorPalette.border, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct OnboardingPermissionView: View {
    let icon: String
    let title: String
    let description: String
    let benefits: [String]
    let permissionGranted: Bool
    let onRequestPermission: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            OnboardingStepHeader(
                icon: icon,
                title: title,
                description: description
            )
            
            VStack(spacing: 12) {
                ForEach(benefits, id: \.self) { benefit in
                    OnboardingFeatureRow(
                        icon: "checkmark.circle.fill",
                        text: benefit
                    )
                }
            }
            .padding(.horizontal)
            
            if permissionGranted {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    Text("Permission Granted")
                        .bodyMedium()
                        .foregroundColor(.green)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.green.opacity(0.1))
                )
                .accessibilityLabel("Permission granted")
            } else {
                CustomButton.primary("Grant Permission") {
                    onRequestPermission()
                }
                .padding(.horizontal)
                .accessibilityHint("Double tap to grant \(title.lowercased())")
            }
            
            Spacer()
        }
        .padding()
    }
}

struct OnboardingNavigationView: View {
    @Binding var currentStep: Int
    let totalSteps: Int
    let canProceed: Bool
    let isLoading: Bool
    let onNext: () -> Void
    let onBack: () -> Void
    let onComplete: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            if currentStep > 0 {
                CustomButton.secondary("Back") {
                    onBack()
                }
                .accessibilityHint("Go back to previous step")
            }
            
            Spacer()
            
            if currentStep < totalSteps - 1 {
                CustomButton.primary(nextButtonTitle) {
                    onNext()
                }
                .disabled(!canProceed)
                .accessibilityHint(canProceed ? "Continue to next step" : "Complete current step to continue")
            } else {
                CustomButton.primary("Get Started") {
                    onComplete()
                }
                .disabled(isLoading)
                .accessibilityHint("Complete onboarding and start using the app")
            }
        }
        .padding()
    }
    
    private var nextButtonTitle: String {
        switch currentStep {
        case 3: return "Continue"
        case 4: return "Continue"
        default: return "Continue"
        }
    }
}

struct OnboardingFeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(ColorPalette.accent)
                .frame(width: 24)
            
            Text(text)
                .bodyMedium()
                .foregroundColor(ColorPalette.textPrimary)
            
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }
}

// MARK: - Onboarding Progress View

struct OnboardingProgressView: View {
    let currentStep: Int
    let totalSteps: Int
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                ForEach(0..<totalSteps, id: \.self) { step in
                    Circle()
                        .fill(step <= currentStep ? ColorPalette.primary : ColorPalette.border)
                        .frame(width: 12, height: 12)
                        .accessibilityLabel("Step \(step + 1)")
                        .accessibilityAddTraits(step <= currentStep ? .isSelected : [])
                    
                    if step < totalSteps - 1 {
                        Rectangle()
                            .fill(step < currentStep ? ColorPalette.primary : ColorPalette.border)
                            .frame(height: 2)
                    }
                }
            }
            .padding(.horizontal)
            
            Text("Step \(currentStep + 1) of \(totalSteps)")
                .captionMedium()
                .foregroundColor(ColorPalette.textSecondary)
                .accessibilityLabel("Current step: \(currentStep + 1) of \(totalSteps)")
        }
        .padding(.top, 20)
        .padding(.bottom, 32)
    }
}

// MARK: - Welcome Step View

struct WelcomeStepView: View {
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                // DeenBuddy logo at the top
                MascotTitleView.homeTitle(titleText: "DeenBuddy")
                    .padding(.bottom, 16)
                
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 80))
                    .foregroundColor(ColorPalette.primary)
                    .accessibilityLabel("DeenBuddy app icon")
                
                VStack(spacing: 8) {
                    Text("Welcome to DeenBuddy")
                        .headlineLarge()
                        .foregroundColor(ColorPalette.textPrimary)
                        .multilineTextAlignment(.center)
                    
                    Text("Your Islamic Prayer Companion")
                        .headlineMedium()
                        .foregroundColor(ColorPalette.accent)
                        .multilineTextAlignment(.center)
                }
            }
            
            Text("DeenBuddy helps you stay connected with your prayers through accurate prayer times, Qibla direction, and guided prayer instructions.")
                .bodyMedium()
                .foregroundColor(ColorPalette.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(nil) // Allow unlimited lines to prevent truncation
                .fixedSize(horizontal: false, vertical: true) // Allow vertical expansion
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                OnboardingFeatureRow(
                    icon: "clock.fill",
                    text: "Accurate prayer times for your location"
                )
                OnboardingFeatureRow(
                    icon: "location.north.fill",
                    text: "Real-time Qibla compass"
                )
                OnboardingFeatureRow(
                    icon: "book.fill",
                    text: "Step-by-step prayer guides"
                )
                OnboardingFeatureRow(
                    icon: "bell.fill",
                    text: "Customizable notifications"
                )
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Welcome to DeenBuddy. Your Islamic Prayer Companion with accurate prayer times, Qibla compass, prayer guides, and notifications.")
    }
}
