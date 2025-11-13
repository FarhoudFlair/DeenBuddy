import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import CoreLocation

/// Enhanced onboarding coordinator that manages the complete flow
public struct EnhancedOnboardingFlow: View {
    private let settingsService: any SettingsServiceProtocol
    private let locationService: any LocationServiceProtocol
    private let notificationService: any NotificationServiceProtocol
    private let userAccountService: any UserAccountServiceProtocol
    private let onShowPremiumTrial: () -> Void
    
    let onComplete: () -> Void
    
    @State private var currentStep = 0
    @State private var userName: String = ""
    @State private var selectedCalculationMethod: CalculationMethod = .muslimWorldLeague
    @State private var selectedMadhab: Madhab = .shafi
    @State private var locationPermissionGranted = false
    @State private var notificationPermissionGranted = false
    @State private var isLoading = false
    @State private var savedUserName: String = ""
    
    // Account step state
    @State private var accountEmail: String = ""
    @State private var accountPassword: String = ""
    @State private var usePassword: Bool = false
    @State private var isSigningIn: Bool = false
    @State private var signInError: String? = nil
    @State private var emailLinkSent: Bool = false

    private let totalSteps = 6
    private let analyticsService = AnalyticsService.shared
    private let accessibilityService = AccessibilityService.shared
    private let localizationService = SharedInstances.localizationService

    private var trimmedUserName: String {
        userName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    public init(
        settingsService: any SettingsServiceProtocol,
        locationService: any LocationServiceProtocol,
        notificationService: any NotificationServiceProtocol,
        userAccountService: any UserAccountServiceProtocol,
        initialStep: Int? = nil,
        onShowPremiumTrial: @escaping () -> Void,
        onComplete: @escaping () -> Void
    ) {
        self.settingsService = settingsService
        self.locationService = locationService
        self.notificationService = notificationService
        self.userAccountService = userAccountService
        self.onShowPremiumTrial = onShowPremiumTrial
        self.onComplete = onComplete

        let coordinate = locationService.currentLocation?.coordinate
            ?? locationService.currentLocationInfo?.coordinate.clLocationCoordinate
        let countryName = locationService.currentLocationInfo?.country
        let defaultConfiguration = DefaultPrayerConfigurationProvider().configuration(
            coordinate: coordinate,
            countryName: countryName
        )
        self._selectedCalculationMethod = State(initialValue: defaultConfiguration.calculationMethod)
        self._selectedMadhab = State(initialValue: defaultConfiguration.madhab)
        print("🧭 Onboarding defaults -> Method: \(defaultConfiguration.calculationMethod.displayName), Madhab: \(defaultConfiguration.madhab.displayName)")

        if let initialStep = initialStep {
            self._currentStep = State(initialValue: min(max(0, initialStep), totalSteps - 1))
        }
    }
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress indicator
                OnboardingProgressView(currentStep: currentStep, totalSteps: totalSteps)
                
                // Content
                TabView(selection: $currentStep) {
                    WelcomeStepView().tag(0)
                    NameCollectionStepView(
                        userName: $userName,
                        isNameValid: !trimmedUserName.isEmpty,
                        onNameSaved: { Task { await saveUserNameImmediately() } }
                    ).tag(1)
                    LocationPermissionStepView(
                        permissionGranted: $locationPermissionGranted,
                        locationService: locationService,
                        userName: trimmedUserName
                    ).tag(2)
                    NotificationPermissionStepView(
                        permissionGranted: $notificationPermissionGranted,
                        notificationService: notificationService,
                        userName: trimmedUserName
                    ).tag(3)
                    PremiumTrialStepView(
                        userName: trimmedUserName,
                        onStartTrial: presentPremiumTrial
                    ).tag(4)
                    AccountEmailStepView(
                        email: $accountEmail,
                        password: $accountPassword,
                        usePassword: $usePassword,
                        isSigningIn: $isSigningIn,
                        signInError: $signInError,
                        emailLinkSent: $emailLinkSent,
                        userAccountService: userAccountService,
                        onSignInSuccess: {
                            Task { await completeOnboarding() }
                        },
                        onSkip: {
                            Task { await completeOnboarding() }
                        }
                    ).tag(5)
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
                    onComplete: { completeOnboarding() }
                )
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            analyticsService.trackScreenView("onboarding_start")
            accessibilityService.announceToVoiceOver("Welcome to DeenBuddy onboarding")
        }
    }
    
    private var canProceed: Bool {
        switch currentStep {
        case 0: return true // Welcome step - no validation needed
        case 1: return !trimmedUserName.isEmpty
        case 2: return locationPermissionGranted // Location permission required
        case 3: return true // Notification permission is optional
        case 4: return true // Premium trial step can always proceed
        default: return true
        }
    }
    
    @MainActor
    private func saveUserNameImmediately() async {
        guard !trimmedUserName.isEmpty else { return }

        // Return early if this name has already been saved
        guard trimmedUserName != savedUserName else { return }

        do {
            settingsService.userName = trimmedUserName
            try await settingsService.saveImmediately()
            print("✅ User name saved immediately: \(trimmedUserName)")

            // Track the successfully saved name
            savedUserName = trimmedUserName

            // Track name collection
            analyticsService.trackUserAction("user_name_collected", parameters: [
                "has_name": true,
                "name_length": trimmedUserName.count
            ])
        } catch {
            print("⚠️ Failed to save user name immediately: \(error.localizedDescription)")
        }
    }
    
    private func nextStep() {
        guard currentStep < totalSteps - 1 else { return }

        dismissKeyboardIfNeeded()

        Task {
            // Manually save user name immediately when advancing from name collection step
            // to avoid losing freshly-typed name if debounce save is cancelled by view disappearing
            if currentStep == 1 { // NameCollectionStep
                await saveUserNameImmediately()
            }

            await MainActor.run {
                analyticsService.trackUserAction("onboarding_step_completed", parameters: ["step": currentStep])

                withAnimation {
                    currentStep += 1
                }

                accessibilityService.announceToVoiceOver("Step \(currentStep + 1) of \(totalSteps)")
            }
        }
    }

#if canImport(UIKit)
    private func dismissKeyboardIfNeeded() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
#else
    private func dismissKeyboardIfNeeded() {}
#endif
    
    private func previousStep() {
        guard currentStep > 0 else { return }

        withAnimation {
            currentStep -= 1
        }

        analyticsService.trackUserAction("onboarding_step_back", parameters: ["step": currentStep])
    }

    private func presentPremiumTrial() {
        analyticsService.trackUserAction(
            "onboarding_premium_trial_tapped",
            parameters: [
                "has_name": !trimmedUserName.isEmpty,
                "step": currentStep
            ]
        )

        onShowPremiumTrial()
    }

    private func completeOnboarding() {
        isLoading = true

        Task {
            print("🚀 Starting onboarding completion...")
            
            do {
                // Save settings sequentially to prevent cascading failures
                await MainActor.run {
                    print("📝 Setting onboarding properties...")
                    settingsService.calculationMethod = selectedCalculationMethod
                    settingsService.madhab = selectedMadhab
                    settingsService.userName = trimmedUserName
                    // Set this last and most critically
                    settingsService.hasCompletedOnboarding = true
                }

                // Use the new onboarding-specific save method with enhanced error handling
                try await settingsService.saveOnboardingSettings()
                print("✅ Onboarding settings saved successfully")
                
            } catch {
                print("⚠️ Error saving onboarding settings: \(error.localizedDescription)")
                print("🔄 Attempting to continue onboarding despite save error...")
                
                // Try to save critical settings individually as fallback
                do {
                    await MainActor.run {
                        // Ensure at minimum that onboarding completion is marked
                        settingsService.hasCompletedOnboarding = true
                    }
                    try await settingsService.saveImmediately()
                    print("✅ Critical onboarding completion saved as fallback")
                } catch {
                    print("❌ Failed to save even critical onboarding settings: \(error.localizedDescription)")
                    // Continue anyway - we'll let the user proceed and retry later
                }
            }
            
            // Sync settings to cloud if user is signed in
            if userAccountService.currentUser != nil {
                do {
                    let snapshot = SettingsSnapshot(
                        calculationMethod: selectedCalculationMethod.rawValue,
                        madhab: selectedMadhab.rawValue,
                        timeFormat: settingsService.timeFormat,
                        notificationsEnabled: settingsService.notificationsEnabled,
                        notificationOffset: settingsService.notificationOffset,
                        liveActivitiesEnabled: settingsService.liveActivitiesEnabled,
                        showArabicSymbolInWidget: settingsService.showArabicSymbolInWidget,
                        userName: trimmedUserName,
                        hasCompletedOnboarding: true,
                        settingsVersion: settingsService.settingsVersion,
                        lastSyncDate: Date()
                    )
                    try await userAccountService.syncSettingsSnapshot(snapshot)
                    print("☁️ Settings synced to cloud after onboarding")
                } catch {
                    print("⚠️ Failed to sync settings to cloud: \(error.localizedDescription)")
                }
            }
            
            // Track completion
            analyticsService.trackUserAction("onboarding_completed", parameters: [
                "calculation_method": selectedCalculationMethod.rawValue,
                "madhab": selectedMadhab.rawValue,
                "location_permission": locationPermissionGranted,
                "notification_permission": notificationPermissionGranted,
                "has_user_name": !userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                "has_account": userAccountService.currentUser != nil
            ])
            
            // Automatically fetch location if permission was granted
            if locationPermissionGranted {
                do {
                    let _ = try await locationService.requestLocation()
                    print("📍 Location fetched automatically after onboarding completion")
                    
                    // Check for "Allow Once" scenario and provide appropriate messaging
                    if let locationService = locationService as? LocationService,
                       let allowOnceMessage = locationService.getAllowOnceMessage() {
                        print("📍 'Allow Once' scenario detected: \(allowOnceMessage)")
                        // The user will see this message in the main app UI
                    }
                } catch {
                    print("⚠️ Failed to fetch location after onboarding: \(error)")
                    
                    // Even if location request fails, check if we have "Allow Once" cached data
                    if let locationService = locationService as? LocationService,
                       let allowOnceMessage = locationService.getAllowOnceMessage() {
                        print("📍 Using 'Allow Once' cached location despite request failure")
                        // This is acceptable - we can still provide service with cached data
                    }
                }
            }
            
            await MainActor.run {
                isLoading = false
                accessibilityService.announceToVoiceOver("Onboarding completed. Welcome to DeenBuddy!")
                onComplete()
            }
        }
    }
}

// MARK: - Supporting Views
//
//private struct OnboardingProgressView: View {
//    let currentStep: Int
//    let totalSteps: Int
//    
//    var body: some View {
//        VStack(spacing: 16) {
//            HStack {
//                ForEach(0..<totalSteps, id: \.self) { step in
//                    Circle()
//                        .fill(step <= currentStep ? ColorPalette.primary : ColorPalette.border)
//                        .frame(width: 12, height: 12)
//                        .accessibilityLabel("Step \(step + 1)")
//                        .accessibilityAddTraits(step <= currentStep ? .isSelected : [])
//                    
//                    if step < totalSteps - 1 {
//                        Rectangle()
//                            .fill(step < currentStep ? ColorPalette.primary : ColorPalette.border)
//                            .frame(height: 2)
//                    }
//                }
//            }
//            .padding(.horizontal)
//            
//            Text("Step \(currentStep + 1) of \(totalSteps)")
//                .captionMedium()
//                .foregroundColor(ColorPalette.textSecondary)
//                .accessibilityLabel("Current step: \(currentStep + 1) of \(totalSteps)")
//        }
//        .padding(.top, 20)
//        .padding(.bottom, 32)
//    }
//}
//
//private struct WelcomeStepView: View {
//    var body: some View {
//        VStack(spacing: 32) {
//            VStack(spacing: 16) {
//                Image(systemName: "moon.stars.fill")
//                    .font(.system(size: 80))
//                    .foregroundColor(ColorPalette.primary)
//                    .accessibilityLabel("DeenBuddy app icon")
//                
//                VStack(spacing: 8) {
//                    Text(LocalizationKeys.welcome.localized)
//                        .headlineLarge()
//                        .foregroundColor(ColorPalette.textPrimary)
//                        .multilineTextAlignment(.center)
//                    
//                    Text("Your Islamic Prayer Companion")
//                        .headlineMedium()
//                        .foregroundColor(ColorPalette.accent)
//                        .multilineTextAlignment(.center)
//                }
//            }
//            
//            Text("DeenBuddy helps you stay connected with your prayers through accurate prayer times, Qibla direction, and guided prayer instructions.")
//                .bodyMedium()
//                .foregroundColor(ColorPalette.textSecondary)
//                .multilineTextAlignment(.center)
//                .padding(.horizontal)
//            
//            VStack(spacing: 12) {
//                OnboardingFeatureRow(
//                    icon: "clock.fill",
//                    text: "Accurate prayer times for your location"
//                )
//                OnboardingFeatureRow(
//                    icon: "location.north.fill",
//                    text: "Real-time Qibla compass"
//                )
//                OnboardingFeatureRow(
//                    icon: "book.fill",
//                    text: "Step-by-step prayer guides"
//                )
//                OnboardingFeatureRow(
//                    icon: "bell.fill",
//                    text: "Customizable notifications"
//                )
//            }
//            .padding(.horizontal)
//            
//            Spacer()
//        }
//        .padding()
//        .accessibilityElement(children: .combine)
//        .accessibilityLabel("Welcome to DeenBuddy. Your Islamic Prayer Companion with accurate prayer times, Qibla compass, prayer guides, and notifications.")
//    }
//}
//
//private struct OnboardingFeatureRow: View {
//    let icon: String
//    let text: String
//    
//    var body: some View {
//        HStack(spacing: 12) {
//            Image(systemName: icon)
//                .foregroundColor(ColorPalette.accent)
//                .frame(width: 24)
//            
//            Text(text)
//                .bodyMedium()
//                .foregroundColor(ColorPalette.textPrimary)
//            
//            Spacer()
//        }
//        .accessibilityElement(children: .combine)
//        .accessibilityLabel(text)
//    }
//}

// MARK: - Unused Onboarding Steps (Commented Out for Future Reference)
// These views are preserved for potential future use. Currently, the onboarding flow
// auto-selects calculation method and madhab based on location (ISNA+Shafi for North America,
// MWL+Shafi elsewhere). If needed in the future, these can be uncommented and added back
// to the TabView in EnhancedOnboardingFlow.

/*
private struct CalculationMethodStepView: View {
    @Binding var selectedMethod: CalculationMethod
    @Binding var selectedMadhab: Madhab
    let userName: String
    
    private var personalizedTitle: String {
        if userName.isEmpty {
            return "Prayer Time Calculation"
        } else {
            return "\(userName), Choose Your Calculation Method"
        }
    }
    
    private var personalizedDescription: String {
        if userName.isEmpty {
            return "Choose the calculation method used in your region for the most accurate prayer times."
        } else {
            return "\(userName), please select the calculation method used in your region for the most accurate prayer times."
        }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            OnboardingStepHeader(
                icon: "clock.fill",
                title: personalizedTitle,
                description: personalizedDescription
            )
            
            // Show current madhab context
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    
                    Text("For \(selectedMadhab.displayName) Madhab")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
                
                Text("Showing methods that work well with your selected madhab")
                    .font(.caption)
                    .foregroundColor(ColorPalette.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal)
            
            ScrollView {
                VStack(spacing: 12) {
                    // Show all calculation methods with compatibility indicators
                    ForEach(CalculationMethod.allCases, id: \.self) { method in
                        CalculationMethodSelectionCard(
                            method: method,
                            madhab: selectedMadhab,
                            isSelected: selectedMethod == method,
                            onSelect: {
                                selectedMethod = method
                                
                                // Auto-adjust madhab if current one is incompatible
                                if !method.isCompatible(with: selectedMadhab) {
                                    if let preferredMadhab = method.preferredMadhab {
                                        selectedMadhab = preferredMadhab
                                        print("🔄 Auto-adjusted madhab to \(preferredMadhab.displayName) for \(method.displayName)")
                                    }
                                }
                                
                                AnalyticsService.shared.trackUserAction("calculation_method_selected", parameters: [
                                    "method": method.rawValue,
                                    "madhab": selectedMadhab.rawValue,
                                    "auto_adjusted": !method.isCompatible(with: selectedMadhab)
                                ])
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
    }
}

private struct CalculationMethodSelectionCard: View {
    let method: CalculationMethod
    let madhab: Madhab
    let isSelected: Bool
    let onSelect: () -> Void
    
    private var isCompatible: Bool {
        method.isCompatible(with: madhab)
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(method.displayName)
                            .bodyMedium()
                            .fontWeight(.medium)
                            .foregroundColor(isCompatible ? ColorPalette.textPrimary : ColorPalette.textSecondary)
                        
                        // Compatibility indicator
                        if !isCompatible {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                        } else if method.preferredMadhab == madhab {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    
                    Text(method.description)
                        .bodySmall()
                        .foregroundColor(isCompatible ? ColorPalette.textSecondary : ColorPalette.textSecondary.opacity(0.7))
                    
                    // Show compatibility or adjustment note
                    if !isCompatible {
                        if let preferredMadhab = method.preferredMadhab {
                            Text("Will adjust madhab to \(preferredMadhab.displayName)")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .padding(.top, 2)
                        } else {
                            Text("May not align with \(madhab.displayName) madhab")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .padding(.top, 2)
                        }
                    } else if method.preferredMadhab == madhab {
                        Text("Designed for \(madhab.displayName)")
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(.top, 2)
                    }
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
                            .stroke(
                                isSelected ? ColorPalette.primary : 
                                isCompatible ? ColorPalette.border : ColorPalette.border.opacity(0.5), 
                                lineWidth: 2
                            )
                    )
            )
            .opacity(isCompatible ? 1.0 : 0.7)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("\(method.displayName). \(method.description)")
        .accessibilityHint("Double tap to select this calculation method")
        .accessibilityValue(isCompatible ? "Compatible with \(madhab.displayName)" : "Less compatible with \(madhab.displayName)")
    }
}

private struct MadhabStepView: View {
    @Binding var selectedMadhab: Madhab
    let selectedCalculationMethod: CalculationMethod
    let userName: String
    
    private var availableMadhabs: [Madhab] {
        // Show all madhabs but mark incompatible ones
        return Madhab.allCases
    }
    
    private var compatibleMadhabs: [Madhab] {
        return Madhab.allCases.filter { madhab in
            selectedCalculationMethod.isCompatible(with: madhab)
        }
    }
    
    private var personalizedTitle: String {
        if userName.isEmpty {
            return "Madhab (Islamic Sect)"
        } else {
            return "\(userName), Select Your Madhab"
        }
    }
    
    private var personalizedDescription: String {
        if userName.isEmpty {
            return "Select your madhab to receive prayer guidance according to your tradition."
        } else {
            return "\(userName), please select your madhab to receive prayer guidance according to your Islamic tradition."
        }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            OnboardingStepHeader(
                icon: "book.fill",
                title: personalizedTitle,
                description: personalizedDescription
            )
            
            // Show calculation method context
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    
                    Text("For \(selectedCalculationMethod.displayName)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
                
                Text("Some madhabs work better with certain calculation methods")
                    .font(.caption)
                    .foregroundColor(ColorPalette.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal)
            
            ScrollView {
                VStack(spacing: 12) {
                    // Show compatible madhabs first
                    ForEach(compatibleMadhabs, id: \.self) { madhab in
                        MadhabSelectionCard(
                            madhab: madhab,
                            calculationMethod: selectedCalculationMethod,
                            isSelected: selectedMadhab == madhab,
                            isCompatible: true
                        ) {
                            selectedMadhab = madhab
                            AnalyticsService.shared.trackUserAction("madhab_selected", parameters: [
                                "madhab": madhab.rawValue,
                                "calculation_method": selectedCalculationMethod.rawValue,
                                "compatible": true
                            ])
                        }
                    }
                    
                    // Show incompatible madhabs if any exist
                    let incompatibleMadhabs = availableMadhabs.filter { !compatibleMadhabs.contains($0) }
                    if !incompatibleMadhabs.isEmpty {
                        Divider()
                            .padding(.vertical, 8)
                        
                        VStack(spacing: 8) {
                            Text("Less Compatible Options")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(ColorPalette.textSecondary)
                            
                            Text("These madhabs may not align perfectly with \(selectedCalculationMethod.displayName)")
                                .font(.caption)
                                .foregroundColor(ColorPalette.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal)
                        
                        ForEach(incompatibleMadhabs, id: \.self) { madhab in
                            MadhabSelectionCard(
                                madhab: madhab,
                                calculationMethod: selectedCalculationMethod,
                                isSelected: selectedMadhab == madhab,
                                isCompatible: false
                            ) {
                                selectedMadhab = madhab
                                AnalyticsService.shared.trackUserAction("madhab_selected", parameters: [
                                    "madhab": madhab.rawValue,
                                    "calculation_method": selectedCalculationMethod.rawValue,
                                    "compatible": false
                                ])
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
    }
}

private struct MadhabSelectionCard: View {
    let madhab: Madhab
    let calculationMethod: CalculationMethod
    let isSelected: Bool
    let isCompatible: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(madhab.displayName)
                            .bodyMedium()
                            .fontWeight(.medium)
                            .foregroundColor(isCompatible ? ColorPalette.textPrimary : ColorPalette.textSecondary)
                        
                        // Compatibility indicator
                        if !isCompatible {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                        } else if calculationMethod.preferredMadhab == madhab {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    
                    Text(madhab.description)
                        .bodySmall()
                        .foregroundColor(isCompatible ? ColorPalette.textSecondary : ColorPalette.textSecondary.opacity(0.7))
                    
                    // Show compatibility note for incompatible madhabs
                    if !isCompatible {
                        Text("May not align with \(calculationMethod.displayName) calculations")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.top, 2)
                    } else if calculationMethod.preferredMadhab == madhab {
                        Text("Recommended for \(calculationMethod.displayName)")
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(.top, 2)
                    }
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
                            .stroke(
                                isSelected ? ColorPalette.primary : 
                                isCompatible ? ColorPalette.border : ColorPalette.border.opacity(0.5), 
                                lineWidth: 2
                            )
                    )
            )
            .opacity(isCompatible ? 1.0 : 0.7)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("\(madhab.displayName). \(madhab.description)")
        .accessibilityHint("Double tap to select this madhab")
        .accessibilityValue(isCompatible ? "Compatible with \(calculationMethod.displayName)" : "Less compatible with \(calculationMethod.displayName)")
    }
}
*/
// End of commented out onboarding steps

private struct LocationPermissionStepView: View {
    @Binding var permissionGranted: Bool
    let locationService: any LocationServiceProtocol
    let userName: String
    
    @State private var isRequestingPermission = false
    @State private var allowOnceMessage: String?
    @State private var permissionError: String?
    
    private var personalizedTitle: String {
        if userName.isEmpty {
            return "Location Access"
        } else {
            return "\(userName), We Need Location Access"
        }
    }
    
    private var personalizedDescription: String {
        if userName.isEmpty {
            return "We need your location to calculate accurate prayer times and Qibla direction for your area."
        } else {
            return "\(userName), we need your location to calculate accurate prayer times and Qibla direction for your area."
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            OnboardingPermissionView(
                icon: "location.fill",
                title: personalizedTitle,
                description: personalizedDescription,
                benefits: [
                    "Precise prayer times for your location",
                    "Accurate Qibla direction",
                    "Automatic time zone adjustments"
                ],
                permissionGranted: permissionGranted,
                onRequestPermission: requestLocationPermission
            )
            
            // Show loading state during permission request
            if isRequestingPermission {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Requesting location permission...")
                        .font(.caption)
                        .foregroundColor(ColorPalette.textSecondary)
                }
                .padding()
            }
            
            // Show permission error if any
            if let error = permissionError {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        
                        Text("Permission Issue")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                    }
                    
                    Text(error)
                        .font(.caption)
                        .foregroundColor(ColorPalette.textSecondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Try Again") {
                        permissionError = nil
                        requestLocationPermission()
                    }
                    .buttonStyle(BorderedProminentButtonStyle())
                    .controlSize(.small)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
            
            // Show "Allow Once" message if applicable
            if let message = allowOnceMessage {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.orange)
                        
                        Text("Limited Location Access")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    }
                    
                    Text(message)
                        .font(.caption)
                        .foregroundColor(ColorPalette.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
        }
        .onAppear {
            checkInitialPermissionStatus()
        }
        .onChange(of: locationService.authorizationStatus) { newStatus in
            // Listen for authorization status changes in real-time
            print("📍 Authorization status changed to: \(newStatus)")
            updatePermissionStatus()
        }
    }
    
    private func updatePermissionStatus() {
        let status = locationService.authorizationStatus
        let wasGranted = permissionGranted
        
        // Update permission status
        permissionGranted = status == .authorizedWhenInUse || status == .authorizedAlways
        
        // Check for "Allow Once" scenario if permission isn't directly granted
        if !permissionGranted {
            if let locationService = locationService as? LocationService {
                allowOnceMessage = locationService.getAllowOnceMessage()
                if allowOnceMessage != nil {
                    // We have cached location data from "Allow Once"
                    permissionGranted = true
                    print("📍 Using existing 'Allow Once' location data for permission")
                }
            }
        }
        
        // Log permission status changes
        if permissionGranted != wasGranted {
            print("📍 Permission status changed: \(wasGranted) → \(permissionGranted) (status: \(status))")
        }
    }
    
    private func checkInitialPermissionStatus() {
        // Use the shared update logic
        updatePermissionStatus()
    }
    
    private func requestLocationPermission() {
        guard !isRequestingPermission else { return }
        
        // Clear any previous errors
        permissionError = nil
        isRequestingPermission = true
        
        Task {
            do {
                print("📍 Requesting location permission...")
                
                // Request permission
                let status = await locationService.requestLocationPermissionAsync()
                
                await MainActor.run {
                    isRequestingPermission = false
                    
                    switch status {
                    case .authorizedWhenInUse, .authorizedAlways:
                        permissionGranted = true
                        print("📍 Location permission granted: \(status)")
                        
                        // Immediately request location to handle "Allow Once"
                        captureLocationImmediately()
                        
                    case .denied:
                        permissionGranted = false
                        permissionError = "Location access was denied. You can enable it later in Settings > Privacy & Security > Location Services."
                        print("📍 Location permission denied")
                        
                    case .restricted:
                        permissionGranted = false
                        permissionError = "Location access is restricted on this device."
                        print("📍 Location permission restricted")
                        
                    case .notDetermined:
                        permissionGranted = false
                        permissionError = "Location permission request failed. Please try again."
                        print("📍 Location permission still not determined")
                        
                    @unknown default:
                        permissionGranted = false
                        permissionError = "Unknown location permission status. Please try again."
                        print("📍 Unknown location permission status: \(status)")
                    }
                }
                
            } catch {
                await MainActor.run {
                    isRequestingPermission = false
                    permissionGranted = false
                    permissionError = "Failed to request location permission: \(error.localizedDescription)"
                    print("📍 Location permission request error: \(error)")
                }
            }
        }
    }
    
    private func captureLocationImmediately() {
        // Immediately capture location for "Allow Once" users
        Task {
            do {
                print("📍 Attempting to capture location immediately...")
                let location = try await locationService.requestLocation()
                print("📍 Successfully captured location: \(location)")
                
                // Check for "Allow Once" scenario
                if let locationService = locationService as? LocationService {
                    await MainActor.run {
                        allowOnceMessage = locationService.getAllowOnceMessage()
                        if allowOnceMessage != nil {
                            print("📍 'Allow Once' location captured and cached")
                        }
                    }
                }
                
            } catch {
                print("📍 Failed to capture location immediately: \(error)")
                
                // Still check for cached "Allow Once" data
                if let locationService = locationService as? LocationService {
                    await MainActor.run {
                        allowOnceMessage = locationService.getAllowOnceMessage()
                        if allowOnceMessage != nil {
                            print("📍 Using cached 'Allow Once' location despite request failure")
                        }
                    }
                }
            }
        }
    }
}

private struct NotificationPermissionStepView: View {
    @Binding var permissionGranted: Bool
    let notificationService: any NotificationServiceProtocol
    let userName: String
    
    @State private var isRequestingPermission = false
    @State private var permissionError: String?
    
    private var personalizedTitle: String {
        if userName.isEmpty {
            return "Prayer Notifications"
        } else {
            return "\(userName), Enable Prayer Reminders"
        }
    }
    
    private var personalizedDescription: String {
        if userName.isEmpty {
            return "Receive gentle reminders for prayer times to help you stay consistent with your prayers."
        } else {
            return "\(userName), receive gentle reminders for prayer times to help you stay consistent with your prayers."
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            OnboardingPermissionView(
                icon: "bell.fill",
                title: personalizedTitle,
                description: personalizedDescription,
                benefits: [
                    "Timely prayer reminders",
                    "Customizable notification sounds", 
                    "Respectful and gentle alerts"
                ],
                permissionGranted: permissionGranted,
                onRequestPermission: requestNotificationPermission
            )
            
            // Show loading state during permission request
            if isRequestingPermission {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Requesting notification permission...")
                        .font(.caption)
                        .foregroundColor(ColorPalette.textSecondary)
                }
                .padding()
            }
            
            // Show permission error if any
            if let error = permissionError {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        
                        Text("Permission Issue")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                    }
                    
                    Text(error)
                        .font(.caption)
                        .foregroundColor(ColorPalette.textSecondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Try Again") {
                        permissionError = nil
                        requestNotificationPermission()
                    }
                    .buttonStyle(BorderedProminentButtonStyle())
                    .controlSize(.small)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
            
            // Optional permission note
            if !permissionGranted && !isRequestingPermission {
                VStack(spacing: 4) {
                    Text("Optional Permission")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(ColorPalette.textSecondary)
                    
                    Text("You can skip this and enable notifications later in Settings")
                        .font(.caption)
                        .foregroundColor(ColorPalette.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
            }
        }
        .onAppear {
            checkInitialPermissionStatus()
        }
        .onChange(of: notificationService.authorizationStatus) { newStatus in
            // Listen for authorization status changes in real-time
            print("🔔 Notification authorization status changed to: \(newStatus)")
            updatePermissionStatus()
        }
    }
    
    private func updatePermissionStatus() {
        let status = notificationService.authorizationStatus
        let wasGranted = permissionGranted
        
        // Update permission status (notifications support both .authorized and .provisional)
        permissionGranted = status == .authorized || status == .provisional
        
        // Log permission status changes for debugging
        if permissionGranted != wasGranted {
            print("🔔 Notification permission status changed: \(wasGranted) → \(permissionGranted) (status: \(status))")
        }
    }
    
    private func checkInitialPermissionStatus() {
        // Use the shared update logic
        updatePermissionStatus()
    }
    
    private func requestNotificationPermission() {
        guard !isRequestingPermission else { return }
        
        // Clear any previous errors
        permissionError = nil
        isRequestingPermission = true
        
        Task {
            do {
                print("🔔 Requesting notification permission...")
                
                let granted = try await notificationService.requestNotificationPermission()
                
                await MainActor.run {
                    isRequestingPermission = false
                    permissionGranted = granted
                    
                    if granted {
                        print("🔔 Notification permission granted")
                    } else {
                        print("🔔 Notification permission denied")
                        permissionError = "Notification access was denied. You can enable it later in Settings > Notifications."
                    }
                }
                
                // Double-check the permission status after a brief delay
                // This helps catch delayed permission updates
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                await MainActor.run {
                    let currentStatus = notificationService.authorizationStatus
                    let finalGranted = currentStatus == .authorized
                    if finalGranted != permissionGranted {
                        print("🔔 Correcting notification permission status: \(finalGranted)")
                        permissionGranted = finalGranted
                        if finalGranted {
                            permissionError = nil
                        }
                    }
                }
                
            } catch {
                await MainActor.run {
                    isRequestingPermission = false
                    permissionGranted = false
                    permissionError = "Failed to request notification permission: \(error.localizedDescription)"
                    print("🔔 Notification permission request error: \(error)")
                }
            }
        }
    }
}

private struct NameCollectionStepView: View {
    @Binding var userName: String
    let isNameValid: Bool
    let onNameSaved: () -> Void
    @FocusState private var isTextFieldFocused: Bool
    @State private var saveTask: Task<Void, Never>?
    
    var body: some View {
        VStack(spacing: 24) {
            OnboardingStepHeader(
                icon: "person.circle.fill",
                title: "What's your name?",
                description: "Help us personalize your experience with a warm Islamic greeting."
            )
            
            VStack(spacing: 16) {
                TextField("Enter your name", text: $userName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.body)
                    .focused($isTextFieldFocused)
                    .submitLabel(.continue)
                    .autocorrectionDisabled()
                    .textContentType(.givenName)
                    .accessibilityLabel("Your name")
                    .accessibilityHint("Enter your preferred name for personalized greetings")
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isNameValid ? Color.clear : Color.red.opacity(0.6), lineWidth: isNameValid ? 0 : 1)
                    )
                    .onSubmit {
                        onNameSaved()
                    }
                    .onChange(of: userName) { newValue in
                        // Debounce saves with a cancellable Task
                        saveTask?.cancel()
                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        saveTask = Task {
                            try? await Task.sleep(nanoseconds: 1_000_000_000)
                            if Task.isCancelled { return }
                            onNameSaved()
                        }
                    }

                if !isNameValid {
                    Text("Please let us know how to greet you.")
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        
                        Text("Your name stays private on your device")
                            .font(.caption)
                            .foregroundColor(ColorPalette.textSecondary)
                    }
                    
                    Text("We'll greet you with \"Assalamu Alaykum\" followed by your name")
                        .font(.caption)
                        .foregroundColor(ColorPalette.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .onAppear {
            // Auto-focus the text field for better UX
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
            }
        }
        .onDisappear {
            // Cancel any pending save when leaving this step
            saveTask?.cancel()
            saveTask = nil
        }
    }
}

private struct PremiumTrialStepView: View {
    let userName: String
    let onStartTrial: () -> Void

    private var personalizedTitle: String {
        if userName.isEmpty {
            return "Try DeenBuddy Premium"
        } else {
            return "\(userName), try DeenBuddy Premium"
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            OnboardingStepHeader(
                icon: "crown.fill",
                title: personalizedTitle,
                description: "Unlock deeper insights, widgets, and exclusive content with a free trial."
            )

            VStack(spacing: 12) {
                OnboardingFeatureRow(
                    icon: "sparkles",
                    text: "Advanced analytics to boost your prayer streaks"
                )
                OnboardingFeatureRow(
                    icon: "chart.line.uptrend.xyaxis",
                    text: "Detailed Tasbih statistics and saved sessions"
                )
                OnboardingFeatureRow(
                    icon: "rectangle.stack.fill.badge.plus",
                    text: "Widgets and live activities tailored for premium"
                )
            }
            .padding(.horizontal)

            CustomButton.primary("Start Free Trial") {
                onStartTrial()
            }
            .padding(.horizontal)

            Text("You can continue without Premium and upgrade anytime from Settings.")
                .font(.caption)
                .foregroundColor(ColorPalette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
        .padding()
    }
}
