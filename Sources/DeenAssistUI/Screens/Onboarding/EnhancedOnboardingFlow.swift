import SwiftUI
import DeenAssistProtocols
import DeenAssistCore

/// Enhanced onboarding coordinator that manages the complete flow
public struct EnhancedOnboardingFlow: View {
    @ObservedObject private var settingsService: any SettingsServiceProtocol
    @ObservedObject private var locationService: any LocationServiceProtocol
    @ObservedObject private var notificationService: any NotificationServiceProtocol
    
    let onComplete: () -> Void
    
    @State private var currentStep = 0
    @State private var selectedCalculationMethod: CalculationMethod = .muslimWorldLeague
    @State private var selectedMadhab: Madhab = .shafi
    @State private var locationPermissionGranted = false
    @State private var notificationPermissionGranted = false
    @State private var isLoading = false
    
    private let totalSteps = 5
    private let analyticsService = AnalyticsService.shared
    private let accessibilityService = AccessibilityService.shared
    private let localizationService = LocalizationService.shared
    
    public init(
        settingsService: any SettingsServiceProtocol,
        locationService: any LocationServiceProtocol,
        notificationService: any NotificationServiceProtocol,
        onComplete: @escaping () -> Void
    ) {
        self.settingsService = settingsService
        self.locationService = locationService
        self.notificationService = notificationService
        self.onComplete = onComplete
    }
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress indicator
                OnboardingProgressView(currentStep: currentStep, totalSteps: totalSteps)
                
                // Content
                TabView(selection: $currentStep) {
                    WelcomeStepView().tag(0)
                    CalculationMethodStepView(
                        selectedMethod: $selectedCalculationMethod
                    ).tag(1)
                    MadhabStepView(
                        selectedMadhab: $selectedMadhab
                    ).tag(2)
                    LocationPermissionStepView(
                        permissionGranted: $locationPermissionGranted,
                        locationService: locationService
                    ).tag(3)
                    NotificationPermissionStepView(
                        permissionGranted: $notificationPermissionGranted,
                        notificationService: notificationService
                    ).tag(4)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut(duration: accessibilityService.getAnimationDuration(0.3)), value: currentStep)
                
                // Navigation buttons
                OnboardingNavigationView(
                    currentStep: $currentStep,
                    totalSteps: totalSteps,
                    canProceed: canProceed,
                    isLoading: isLoading,
                    onNext: nextStep,
                    onBack: previousStep,
                    onComplete: completeOnboarding
                )
            }
            .navigationBarHidden(true)
            .localizedLayout()
        }
        .onAppear {
            analyticsService.trackScreenView("onboarding_start")
            accessibilityService.announceToVoiceOver("Welcome to Deen Assist onboarding")
        }
    }
    
    private var canProceed: Bool {
        switch currentStep {
        case 3: return locationPermissionGranted
        case 4: return true // Notification permission is optional
        default: return true
        }
    }
    
    private func nextStep() {
        guard currentStep < totalSteps - 1 else { return }
        
        analyticsService.trackUserAction("onboarding_step_completed", parameters: ["step": currentStep])
        
        withAnimation {
            currentStep += 1
        }
        
        accessibilityService.announceToVoiceOver("Step \(currentStep + 1) of \(totalSteps)")
    }
    
    private func previousStep() {
        guard currentStep > 0 else { return }
        
        withAnimation {
            currentStep -= 1
        }
        
        analyticsService.trackUserAction("onboarding_step_back", parameters: ["step": currentStep])
    }
    
    private func completeOnboarding() {
        isLoading = true
        
        Task {
            // Save settings
            await MainActor.run {
                settingsService.calculationMethod = selectedCalculationMethod
                settingsService.madhab = selectedMadhab
                settingsService.hasCompletedOnboarding = true
            }
            
            try? await settingsService.saveSettings()
            
            // Track completion
            analyticsService.trackUserAction("onboarding_completed", parameters: [
                "calculation_method": selectedCalculationMethod.rawValue,
                "madhab": selectedMadhab.rawValue,
                "location_permission": locationPermissionGranted,
                "notification_permission": notificationPermissionGranted
            ])
            
            await MainActor.run {
                isLoading = false
                accessibilityService.announceToVoiceOver("Onboarding completed. Welcome to Deen Assist!")
                onComplete()
            }
        }
    }
}

// MARK: - Supporting Views

private struct OnboardingProgressView: View {
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

private struct WelcomeStepView: View {
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 16) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 80))
                    .foregroundColor(ColorPalette.primary)
                    .accessibilityLabel("Deen Assist app icon")
                
                VStack(spacing: 8) {
                    Text(LocalizationKeys.welcome.localized)
                        .headlineLarge()
                        .foregroundColor(ColorPalette.textPrimary)
                        .multilineTextAlignment(.center)
                    
                    Text("Your Islamic Prayer Companion")
                        .headlineMedium()
                        .foregroundColor(ColorPalette.accent)
                        .multilineTextAlignment(.center)
                }
            }
            
            Text("Deen Assist helps you stay connected with your prayers through accurate prayer times, Qibla direction, and guided prayer instructions.")
                .bodyMedium()
                .foregroundColor(ColorPalette.textSecondary)
                .multilineTextAlignment(.center)
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
        .accessibilityLabel("Welcome to Deen Assist. Your Islamic Prayer Companion with accurate prayer times, Qibla compass, prayer guides, and notifications.")
    }
}

private struct OnboardingFeatureRow: View {
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

private struct CalculationMethodStepView: View {
    @Binding var selectedMethod: CalculationMethod
    
    var body: some View {
        VStack(spacing: 24) {
            OnboardingStepHeader(
                icon: "clock.fill",
                title: "Prayer Time Calculation",
                description: "Choose the calculation method used in your region for the most accurate prayer times."
            )
            
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(CalculationMethod.allCases, id: \.self) { method in
                        OnboardingSelectionCard(
                            title: method.displayName,
                            description: method.description,
                            isSelected: selectedMethod == method
                        ) {
                            selectedMethod = method
                            AnalyticsService.shared.trackUserAction("calculation_method_selected", parameters: ["method": method.rawValue])
                        }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityLabel("\(method.displayName). \(method.description)")
                        .accessibilityHint("Double tap to select this calculation method")
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
    }
}

private struct MadhabStepView: View {
    @Binding var selectedMadhab: Madhab
    
    var body: some View {
        VStack(spacing: 24) {
            OnboardingStepHeader(
                icon: "book.fill",
                title: "Islamic School of Thought",
                description: "Select your madhab to receive prayer guidance according to your tradition."
            )
            
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Madhab.allCases, id: \.self) { madhab in
                        OnboardingSelectionCard(
                            title: madhab.displayName,
                            description: madhab.description,
                            isSelected: selectedMadhab == madhab
                        ) {
                            selectedMadhab = madhab
                            AnalyticsService.shared.trackUserAction("madhab_selected", parameters: ["madhab": madhab.rawValue])
                        }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityLabel("\(madhab.displayName). \(madhab.description)")
                        .accessibilityHint("Double tap to select this madhab")
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
    }
}

private struct LocationPermissionStepView: View {
    @Binding var permissionGranted: Bool
    let locationService: any LocationServiceProtocol
    
    var body: some View {
        OnboardingPermissionView(
            icon: "location.fill",
            title: "Location Access",
            description: "We need your location to calculate accurate prayer times and Qibla direction for your area.",
            benefits: [
                "Precise prayer times for your location",
                "Accurate Qibla direction",
                "Automatic time zone adjustments"
            ],
            permissionGranted: permissionGranted,
            onRequestPermission: requestLocationPermission
        )
    }
    
    private func requestLocationPermission() {
        Task {
            let status = await locationService.requestLocationPermission()
            await MainActor.run {
                permissionGranted = status == .authorized
            }
        }
    }
}

private struct NotificationPermissionStepView: View {
    @Binding var permissionGranted: Bool
    let notificationService: any NotificationServiceProtocol
    
    var body: some View {
        OnboardingPermissionView(
            icon: "bell.fill",
            title: "Prayer Notifications",
            description: "Receive gentle reminders for prayer times to help you stay consistent with your prayers.",
            benefits: [
                "Timely prayer reminders",
                "Customizable notification sounds",
                "Respectful and gentle alerts"
            ],
            permissionGranted: permissionGranted,
            onRequestPermission: requestNotificationPermission
        )
    }
    
    private func requestNotificationPermission() {
        Task {
            let granted = await notificationService.requestPermission()
            await MainActor.run {
                permissionGranted = granted
            }
        }
    }
}
