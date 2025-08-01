import SwiftUI

/// Enhanced onboarding coordinator that manages the complete flow
public struct EnhancedOnboardingFlow: View {
    private let settingsService: any SettingsServiceProtocol
    private let locationService: any LocationServiceProtocol
    private let notificationService: any NotificationServiceProtocol
    
    let onComplete: () -> Void
    
    @State private var currentStep = 0
    @State private var userName: String = ""
    @State private var selectedCalculationMethod: CalculationMethod = .muslimWorldLeague
    @State private var selectedMadhab: Madhab = .shafi
    @State private var locationPermissionGranted = false
    @State private var notificationPermissionGranted = false
    @State private var isLoading = false
    
    private let totalSteps = 6
    private let analyticsService = AnalyticsService.shared
    private let accessibilityService = AccessibilityService.shared
    private let localizationService = SharedInstances.localizationService
    
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
                    NameCollectionStepView(
                        userName: $userName
                    ).tag(1)
                    MadhabStepView(
                        selectedMadhab: $selectedMadhab
                    ).tag(2)
                    CalculationMethodStepView(
                        selectedMethod: $selectedCalculationMethod,
                        selectedMadhab: selectedMadhab
                    ).tag(3)
                    LocationPermissionStepView(
                        permissionGranted: $locationPermissionGranted,
                        locationService: locationService
                    ).tag(4)
                    NotificationPermissionStepView(
                        permissionGranted: $notificationPermissionGranted,
                        notificationService: notificationService
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
                    onComplete: completeOnboarding
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
        case 4: return locationPermissionGranted
        case 5: return true // Notification permission is optional
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
            print("🚀 Starting onboarding completion...")
            
            do {
                // Save settings sequentially to prevent cascading failures
                await MainActor.run {
                    print("📝 Setting onboarding properties...")
                    settingsService.calculationMethod = selectedCalculationMethod
                    settingsService.madhab = selectedMadhab
                    settingsService.userName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
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
            
            // Track completion
            analyticsService.trackUserAction("onboarding_completed", parameters: [
                "calculation_method": selectedCalculationMethod.rawValue,
                "madhab": selectedMadhab.rawValue,
                "location_permission": locationPermissionGranted,
                "notification_permission": notificationPermissionGranted,
                "has_user_name": !userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

private struct CalculationMethodStepView: View {
    @Binding var selectedMethod: CalculationMethod
    let selectedMadhab: Madhab
    
    private var compatibleMethods: [CalculationMethod] {
        CalculationMethod.allCases.filter { method in
            method.isCompatible(with: selectedMadhab)
        }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            OnboardingStepHeader(
                icon: "clock.fill",
                title: "Prayer Time Calculation",
                description: "Choose the calculation method used in your region for the most accurate prayer times."
            )
            
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(compatibleMethods, id: \.self) { method in
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
                title: "Madhab (Sect)",
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
    
    @State private var isRequestingPermission = false
    @State private var allowOnceMessage: String?
    @State private var showingAllowOnceAlert = false
    
    var body: some View {
        VStack(spacing: 16) {
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
            // Check initial permission status
            updatePermissionStatus()
            
            // Set up periodic permission monitoring for "Allow Once" detection
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
                Task { @MainActor in
                    let newStatus = locationService.authorizationStatus
                    if newStatus != .notDetermined {
                        updatePermissionStatus()
                        if permissionGranted {
                            timer.invalidate()
                        }
                    }
                    
                    // Check for "Allow Once" message updates
                    if let locationService = locationService as? LocationService {
                        allowOnceMessage = locationService.getAllowOnceMessage()
                    }
                }
            }
        }
    }
    
    private func updatePermissionStatus() {
        let status = locationService.authorizationStatus
        let wasGranted = permissionGranted
        permissionGranted = status == .authorizedWhenInUse || status == .authorizedAlways
        
        // If permission was just granted, try to get location immediately
        if !wasGranted && permissionGranted && !isRequestingPermission {
            captureLocationImmediately()
        }
        
        // Update "Allow Once" message
        if let locationService = locationService as? LocationService {
            allowOnceMessage = locationService.getAllowOnceMessage()
        }
    }
    
    private func requestLocationPermission() {
        guard !isRequestingPermission else { return }
        isRequestingPermission = true
        
        Task {
            let status = await locationService.requestLocationPermissionAsync()
            await MainActor.run {
                let wasPermissionGranted = permissionGranted
                permissionGranted = status == .authorizedWhenInUse || status == .authorizedAlways
                isRequestingPermission = false
                
                // If permission granted, immediately capture location for "Allow Once" case
                if permissionGranted {
                    captureLocationImmediately()
                } else if status == .denied && !wasPermissionGranted {
                    // User might have selected "Allow Once" and permission already expired
                    checkForAllowOnceScenario()
                }
            }
        }
    }
    
    private func captureLocationImmediately() {
        // CRITICAL: Capture location immediately for "Allow Once" users
        // This ensures we get the location before permission potentially expires
        Task {
            do {
                let location = try await locationService.requestLocation()
                print("📍 Successfully captured location during onboarding: \(location)")
                
                // Check if this might be an "Allow Once" scenario
                if let locationService = locationService as? LocationService {
                    let message = locationService.getAllowOnceMessage()
                    await MainActor.run {
                        allowOnceMessage = message
                        if message != nil {
                            print("📍 Detected 'Allow Once' scenario during onboarding")
                        }
                    }
                }
            } catch {
                print("📍 Failed to capture location during onboarding: \(error)")
                
                // Check if we can still use "Allow Once" cached location
                await MainActor.run {
                    checkForAllowOnceScenario()
                }
            }
        }
    }
    
    private func checkForAllowOnceScenario() {
        // Check if we have an "Allow Once" cached location we can use
        if let locationService = locationService as? LocationService {
            allowOnceMessage = locationService.getAllowOnceMessage()
            
            // If we have a valid "Allow Once" location, we can still proceed
            if allowOnceMessage != nil {
                print("📍 Found 'Allow Once' cached location, allowing user to proceed")
                // Consider this as permission granted for onboarding purposes
                // since we have the location data we need
                permissionGranted = true
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
            do {
                let granted = try await notificationService.requestNotificationPermission()
                await MainActor.run {
                    permissionGranted = granted
                }
            } catch {
                await MainActor.run {
                    permissionGranted = false
                }
            }
        }
    }
}

private struct NameCollectionStepView: View {
    @Binding var userName: String
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            OnboardingStepHeader(
                icon: "person.circle.fill",
                title: "What's your name?",
                description: "Help us personalize your experience with a warm Islamic greeting."
            )
            
            VStack(spacing: 16) {
                TextField("Enter your name (optional)", text: $userName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.body)
                    .focused($isTextFieldFocused)
                    .submitLabel(.continue)
                    .autocorrectionDisabled()
                    .textContentType(.givenName)
                    .accessibilityLabel("Your name")
                    .accessibilityHint("Enter your preferred name for personalized greetings")
                
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
    }
}
