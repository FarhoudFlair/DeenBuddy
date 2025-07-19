import SwiftUI
import Combine
import BackgroundTasks

/// Main app coordinator that manages navigation and app state
@MainActor
public class AppCoordinator: ObservableObject {

    // MARK: - Published Properties

    @Published public var currentScreen: AppScreen = .loading
    @Published public var showingSettings = false
    @Published public var showingCompass = false
    @Published public var showingARCompass = false
    @Published public var showingGuides = false
    @Published public var showingQuranSearch = false
    @Published public var showingError = false
    @Published public var currentError: ErrorType?
    @Published public var isLoading = false
    @Published public var navigationPath = NavigationPath()

    // MARK: - Services

    public let locationService: any LocationServiceProtocol
    public let notificationService: any NotificationServiceProtocol
    public let prayerTimeService: any PrayerTimeServiceProtocol
    public let prayerTrackingService: any PrayerTrackingServiceProtocol
    public let prayerAnalyticsService: any PrayerAnalyticsServiceProtocol
    public let settingsService: any SettingsServiceProtocol
    public let themeManager: ThemeManager
    private let backgroundTaskManager: BackgroundTaskManager
    private let backgroundPrayerRefreshService: BackgroundPrayerRefreshService

    // MARK: - Enhanced Services

    private let analyticsService = SharedInstances.analyticsService
    private let accessibilityService = SharedInstances.accessibilityService
    private let localizationService = SharedInstances.localizationService
    private let performanceMonitor = PerformanceMonitor.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init(
        locationService: any LocationServiceProtocol,
        notificationService: any NotificationServiceProtocol,
        prayerTimeService: any PrayerTimeServiceProtocol,
        prayerTrackingService: any PrayerTrackingServiceProtocol,
        prayerAnalyticsService: any PrayerAnalyticsServiceProtocol,
        settingsService: any SettingsServiceProtocol,
        themeManager: ThemeManager,
        backgroundTaskManager: BackgroundTaskManager,
        backgroundPrayerRefreshService: BackgroundPrayerRefreshService
    ) {
        self.locationService = locationService
        self.notificationService = notificationService
        self.prayerTimeService = prayerTimeService
        self.prayerTrackingService = prayerTrackingService
        self.prayerAnalyticsService = prayerAnalyticsService
        self.settingsService = settingsService
        self.themeManager = themeManager
        self.backgroundTaskManager = backgroundTaskManager
        self.backgroundPrayerRefreshService = backgroundPrayerRefreshService

        setupInitialState()
        setupEnhancedServices()
    }
    
    // MARK: - Public Methods
    
    public func start() {
        Task {
            // PERFORMANCE: Start performance monitoring early
            PerformanceMonitoringService.shared.startMonitoring()

            await loadSettings()
            await determineInitialScreen()

            // PERFORMANCE: Log startup metrics
            let report = PerformanceMonitoringService.shared.getPerformanceReport()
            print("🚀 App startup completed - \(report.summary)")
        }
    }
    
    // MARK: - Navigation Methods

    public func showHome() {
        withAnimation(.easeInOut) {
            currentScreen = .home
        }
    }

    public func showOnboarding() {
        withAnimation(.easeInOut) {
            currentScreen = .onboarding(.welcome)
        }
    }

    public func showSettings() {
        showingSettings = true
    }

    public func dismissSettings() {
        showingSettings = false
    }

    public func showCompass() {
        showingCompass = true
    }

    public func dismissCompass() {
        showingCompass = false
    }

    public func showARCompass() {
        showingARCompass = true
    }

    public func dismissARCompass() {
        showingARCompass = false
    }

    public func showGuides() {
        showingGuides = true
    }

    public func dismissGuides() {
        showingGuides = false
    }

    public func showQuranSearch() {
        showingQuranSearch = true
    }

    public func dismissQuranSearch() {
        showingQuranSearch = false
    }

    public func showError(_ error: ErrorType) {
        currentError = error
        showingError = true
    }

    public func dismissError() {
        currentError = nil
        showingError = false
    }

    public func setLoading(_ loading: Bool) {
        withAnimation(.easeInOut(duration: 0.3)) {
            isLoading = loading
        }
    }

    public func completeOnboarding() {
        Task {
            print("🏁 AppCoordinator completing onboarding...")
            
            await MainActor.run {
                settingsService.hasCompletedOnboarding = true
            }
            
            do {
                // Use immediate save for critical onboarding completion
                try await settingsService.saveImmediately()
                print("✅ Onboarding completion saved successfully in AppCoordinator")
            } catch is CancellationError {
                // Handle cancellation gracefully - this is normal if the task is cancelled
                print("ℹ️ Onboarding completion save was cancelled (this is normal)")
                // Continue anyway - the app should still transition to home
            } catch {
                print("⚠️ Error saving onboarding completion in AppCoordinator: \(error.localizedDescription)")
                // Continue anyway - the app should still transition to home
            }
            
            await MainActor.run {
                withAnimation(.easeInOut) {
                    currentScreen = .home
                }
                print("🏠 Transitioned to home screen")
            }
        }
    }

    public func handleDeepLink(_ url: URL) {
        // Handle deep linking for future features
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let host = components.host else { return }

        switch host {
        case "settings":
            showSettings()
        case "compass":
            showCompass()
        case "guides":
            showGuides()
        default:
            break
        }
    }
    
    // MARK: - Private Methods
    
    private func setupInitialState() {
        currentScreen = .loading
    }

    private func setupEnhancedServices() {
        // Start performance monitoring
        performanceMonitor.startMonitoring()

        // Track app launch
        analyticsService.trackEvent(.sessionStarted)

        // Setup accessibility observers
        accessibilityService.$isVoiceOverEnabled
            .sink { [weak self] isEnabled in
                if isEnabled {
                    self?.accessibilityService.announceToVoiceOver("DeenBuddy is ready")
                }
            }
            .store(in: &cancellables)

        // Setup localization observers
        NotificationCenter.default.publisher(for: .languageChanged)
            .sink { [weak self] _ in
                self?.accessibilityService.postLayoutChangeNotification()
            }
            .store(in: &cancellables)

        // Initialize background services
        Task {
            do {
                // Register background tasks
                backgroundTaskManager.registerBackgroundTasks()
                print("📋 Background task registration initiated")

                // Start background prayer refresh
                backgroundPrayerRefreshService.startBackgroundRefresh()
                print("🕌 Background prayer refresh service started")
            } catch {
                print("❌ Failed to initialize background services: \(error)")
                // Continue execution - background services are not critical for app functionality
            }
        }

        print("🚀 Enhanced services initialized")
    }


    
    private func loadSettings() async {
        do {
            try await settingsService.loadSettings()
        } catch is CancellationError {
            // Handle cancellation gracefully - this is normal if the task is cancelled
            print("ℹ️ Settings loading was cancelled (this is normal)")
        } catch {
            print("Failed to load settings: \(error)")
        }
    }
    
    private func determineInitialScreen() async {
        // Simulate loading time
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        print("🚀 Determining initial screen...")
        print("📋 Onboarding completed: \(settingsService.hasCompletedOnboarding)")
        print("📍 Location status: \(locationService.authorizationStatus)")
        
        // Check if onboarding is completed
        if !settingsService.hasCompletedOnboarding {
            print("📋 Showing onboarding welcome screen")
            currentScreen = .onboarding(.welcome)
            return
        }
        
        // Check location permission
        let locationStatus = locationService.authorizationStatus
        if locationStatus == .notDetermined {
            // If location permission not determined, show location permission onboarding
            print("📍 Location permission not determined, showing location permission screen")
            currentScreen = .onboarding(.locationPermission)
            return
        }
        
        if locationStatus == .denied || locationStatus == .restricted {
            // If location permission denied, we can still show home but with error message
            // The prayer times view will handle displaying an appropriate error
            print("📍 Location permission denied/restricted, showing home with error handling")
            currentScreen = .home
            return
        }
        
        // All good, show home
        print("✅ All permissions good, showing home screen")
        currentScreen = .home
    }
}

// MARK: - App Screens

public enum AppScreen: Equatable {
    case loading
    case onboarding(OnboardingStep)
    case home
}

public enum OnboardingStep: Equatable {
    case welcome
    case locationPermission
    case calculationMethod
    case notificationPermission
}

// MARK: - Main App View

public struct DeenAssistApp: View {
    @StateObject private var coordinator: AppCoordinator
    
    public init(coordinator: AppCoordinator) {
        self._coordinator = StateObject(wrappedValue: coordinator)
    }
    
    public var body: some View {
        Group {
            switch coordinator.currentScreen {
            case .loading:
                LoadingView.prayer(message: "Loading DeenBuddy...")
                
            case .onboarding(let step):
                OnboardingCoordinatorView(
                    step: step,
                    coordinator: coordinator
                )
                
            case .home:
                // Use the functional tab view implementation
                SimpleTabView(coordinator: coordinator)
            }
        }
        .onAppear {
            coordinator.start()
        }
    }
}

// MARK: - Onboarding Coordinator View

public struct OnboardingCoordinatorView: View {
    let step: OnboardingStep
    let coordinator: AppCoordinator
    
    @State private var currentStep: OnboardingStep
    
    public init(step: OnboardingStep, coordinator: AppCoordinator) {
        self.step = step
        self.coordinator = coordinator
        self._currentStep = State(initialValue: step)
    }
    
    public var body: some View {
        Group {
            switch currentStep {
            case .welcome:
                WelcomeScreen {
                    currentStep = .locationPermission
                }
                
            case .locationPermission:
                LocationPermissionScreen(
                    locationService: coordinator.locationService,
                    onContinue: {
                        currentStep = .calculationMethod
                    },
                    onSkip: {
                        currentStep = .calculationMethod
                    }
                )
                
            case .calculationMethod:
                CalculationMethodScreen(
                    settingsService: coordinator.settingsService,
                    onContinue: {
                        currentStep = .notificationPermission
                    }
                )
                
            case .notificationPermission:
                NotificationPermissionScreen(
                    notificationService: coordinator.notificationService,
                    settingsService: coordinator.settingsService,
                    onComplete: {
                        coordinator.completeOnboarding()
                    }
                )
            }
        }
        .transition(.slide)
        .animation(.easeInOut, value: currentStep)
    }
}

// MARK: - Main App View

private struct MainAppView: View {
    @ObservedObject private var coordinator: AppCoordinator

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    var body: some View {
        ZStack {
            HomeScreen(
                prayerTimeService: coordinator.prayerTimeService,
                locationService: coordinator.locationService,
                settingsService: coordinator.settingsService,
                notificationService: coordinator.notificationService,
                onCompassTapped: { }, // No action needed - available as tab
                onGuidesTapped: { }, // No action needed - available as tab
                onQuranSearchTapped: { }, // No action needed - available as tab
                onSettingsTapped: { }, // No action needed - available as tab
                onNotificationsTapped: {
                    // Bell icon tapped - notification settings functionality
                    print("Notification bell tapped")
                }
            )

            // Loading overlay
            if coordinator.isLoading {
                LoadingOverlay()
            }
        }
        .fullScreenCover(isPresented: $coordinator.showingARCompass) {
            ARQiblaCompassScreen(
                locationService: coordinator.locationService,
                onDismiss: {
                    coordinator.dismissARCompass()
                }
            )
        }
        .errorAlert()
        .themed(with: coordinator.themeManager)
    }
}

// MARK: - Placeholder Views for Future Features

private struct CompassPlaceholderView: View {
    let onDismiss: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "safari.fill")
                    .font(.system(size: 80))
                    .foregroundColor(ColorPalette.primary)

                Text("Qibla Compass")
                    .headlineLarge()
                    .foregroundColor(ColorPalette.textPrimary)

                Text("This feature is being developed by Engineer 4 and will be available soon.")
                    .bodyMedium()
                    .foregroundColor(ColorPalette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                CustomButton.primary("Coming Soon") {
                    onDismiss()
                }
            }
            .navigationTitle("Qibla Compass")
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
}

private struct GuidesPlaceholderView: View {
    let onDismiss: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "book.fill")
                    .font(.system(size: 80))
                    .foregroundColor(ColorPalette.secondary)

                Text("Prayer Guides")
                    .headlineLarge()
                    .foregroundColor(ColorPalette.textPrimary)

                Text("Comprehensive prayer guides for Sunni and Shia prayers are being developed by Engineer 4.")
                    .bodyMedium()
                    .foregroundColor(ColorPalette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                CustomButton.primary("Coming Soon") {
                    onDismiss()
                }
            }
            .navigationTitle("Prayer Guides")
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
}

private struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)

                Text("Loading...")
                    .foregroundColor(.white)
                    .font(.headline)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.8))
            )
        }
    }
}

// MARK: - Simple Tab View

private struct SimpleTabView: View {
    @ObservedObject private var coordinator: AppCoordinator
    
    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }
    
    var body: some View {
        TabView {
            // 1. Home Tab - Prayer times and main dashboard
            MainAppView(coordinator: coordinator)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
            
            // 2. Qibla Tab - Direct access to compass
            QiblaCompassScreen(
                locationService: coordinator.locationService,
                onDismiss: { }, // No dismiss needed in tab mode
                onShowAR: {
                    coordinator.showARCompass()
                }
            )
            .tabItem {
                Image(systemName: "safari.fill")
                Text("Qibla")
            }
            
            // 3. Prayer Tracking Tab - Direct access to prayer tracking
            PrayerTrackingScreen(
                prayerTrackingService: coordinator.prayerTrackingService,
                prayerTimeService: coordinator.prayerTimeService,
                notificationService: coordinator.notificationService,
                onDismiss: { } // No dismiss needed in tab mode
            )
            .tabItem {
                Image(systemName: "checkmark.circle.fill")
                Text("Tracking")
            }
            
            // 4. Quran Tab - Direct access to QuranSearchView
            QuranSearchView()
                .tabItem {
                    Image(systemName: "book.fill")
                    Text("Quran")
                }
            
            // 5. Settings Tab - Enhanced settings view with full functionality
            EnhancedSettingsView(
                settingsService: coordinator.settingsService as! SettingsService,
                themeManager: coordinator.themeManager,
                onDismiss: { } // No dismiss needed in tab mode
            )
            .tabItem {
                Image(systemName: "gear")
                Text("Settings")
            }
        }
        .accentColor(ColorPalette.primary)
        .themed(with: coordinator.themeManager)
    }
}

// MARK: - Convenience Extensions

public extension AppCoordinator {
    /// Create coordinator with mock services for previews and testing
    static func mock() -> AppCoordinator {
        let container = DependencyContainer.createForTesting()
        let themeManager = ThemeManager(settingsService: container.settingsService)

        return AppCoordinator(
            locationService: container.locationService,
            notificationService: container.notificationService,
            prayerTimeService: container.prayerTimeService,
            prayerTrackingService: container.prayerTrackingService,
            prayerAnalyticsService: container.prayerAnalyticsService,
            settingsService: container.settingsService,
            themeManager: themeManager,
            backgroundTaskManager: container.backgroundTaskManager,
            backgroundPrayerRefreshService: container.backgroundPrayerRefreshService
        )
    }

    /// Create coordinator with real services for production
    static func production() -> AppCoordinator {
        let container = DependencyContainer.shared
        let themeManager = ThemeManager(settingsService: container.settingsService)

        return AppCoordinator(
            locationService: container.locationService,
            notificationService: container.notificationService,
            prayerTimeService: container.prayerTimeService,
            prayerTrackingService: container.prayerTrackingService,
            prayerAnalyticsService: container.prayerAnalyticsService,
            settingsService: container.settingsService,
            themeManager: themeManager,
            backgroundTaskManager: container.backgroundTaskManager,
            backgroundPrayerRefreshService: container.backgroundPrayerRefreshService
        )
    }
}
