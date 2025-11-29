import SwiftUI

/// Islamic Calendar & Future Prayer Times main screen
/// Displays date picker, prayer times, events, and Islamic accuracy disclaimers
public struct IslamicCalendarScreen: View {

    // MARK: - Dependencies (Injected via init)

    private let prayerTimeService: any PrayerTimeServiceProtocol
    private let islamicCalendarService: any IslamicCalendarServiceProtocol
    private let locationService: any LocationServiceProtocol
    private let settingsService: any SettingsServiceProtocol

    // MARK: - Navigation Callbacks

    let onDismiss: () -> Void
    let onSettingsTapped: () -> Void

    // MARK: - ViewModel

    @StateObject private var viewModel: IslamicCalendarViewModel

    // MARK: - Environment

    @Environment(\.currentTheme) private var currentTheme
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - State

    @State private var hasAppeared = false

    // MARK: - Initialization

    public init(
        prayerTimeService: any PrayerTimeServiceProtocol,
        islamicCalendarService: any IslamicCalendarServiceProtocol,
        locationService: any LocationServiceProtocol,
        settingsService: any SettingsServiceProtocol,
        onDismiss: @escaping () -> Void,
        onSettingsTapped: @escaping () -> Void
    ) {
        self.prayerTimeService = prayerTimeService
        self.islamicCalendarService = islamicCalendarService
        self.locationService = locationService
        self.settingsService = settingsService
        self.onDismiss = onDismiss
        self.onSettingsTapped = onSettingsTapped

        // Create ViewModel with services
        _viewModel = StateObject(wrappedValue: IslamicCalendarViewModel(
            prayerTimeService: prayerTimeService,
            islamicCalendarService: islamicCalendarService,
            locationService: locationService,
            settingsService: settingsService
        ))
    }

    // MARK: - Body

    public var body: some View {
        NavigationView {
            ZStack {
                // Background
                themeColors.backgroundPrimary
                    .ignoresSafeArea()

                // Main content
                ScrollView {
                    VStack(spacing: PremiumDesignTokens.spacing16) {
                        // 1. Disclaimer banner (if not today)
                        if !viewModel.isToday && viewModel.disclaimerLevel != .today {
                            DisclaimerBanner(
                                variant: viewModel.disclaimerVariant,
                                isVisible: $viewModel.showDisclaimer,
                                forceShow: true  // Always show in production
                            )
                            .appAnimation(
                                AppAnimations.staggeredEntry(delay: 0.1),
                                value: hasAppeared
                            )
                        }

                        // 2. High-latitude warning (if applicable)
                        if viewModel.showHighLatitudeWarning {
                            DisclaimerBanner.highLatitude(
                                isVisible: .constant(true),
                                forceShow: true
                            )
                            .appAnimation(
                                AppAnimations.staggeredEntry(delay: 0.2),
                                value: hasAppeared
                            )
                        }

                        // 3. Islamic Date Picker
                        IslamicDatePicker(
                            selectedDate: $viewModel.selectedDate,
                            islamicEvents: viewModel.islamicEvents,
                            maxLookaheadDate: viewModel.maxLookaheadDate
                        )
                        .appAnimation(
                            AppAnimations.staggeredEntry(delay: 0.3),
                            value: hasAppeared
                        )

                        // 4. Islamic Event Card (if events on selected date)
                        if let event = viewModel.eventOnSelectedDate {
                            IslamicEventCard(event: event)
                                .appAnimation(
                                    AppAnimations.staggeredEntry(delay: 0.4),
                                    value: hasAppeared
                                )
                        }

                        // 5. Prayer times list
                        if let result = viewModel.prayerTimeResult {
                            FuturePrayerTimesList(
                                prayerTimeResult: result,
                                showRakahCount: false
                            )
                            .appAnimation(
                                AppAnimations.staggeredEntry(delay: 0.5),
                                value: hasAppeared
                            )
                        } else if viewModel.isLoading {
                            loadingView
                        }

                        // 6. Calculation info footer
                        if let result = viewModel.prayerTimeResult {
                            CalculationInfoFooter(
                                calculationMethod: viewModel.calculationMethod,
                                madhab: viewModel.madhab,
                                isRamadan: result.isRamadan,
                                calculationTimezone: result.calculationTimezone,
                                onSettingsTapped: onSettingsTapped
                            )
                            .appAnimation(
                                AppAnimations.staggeredEntry(delay: 0.6),
                                value: hasAppeared
                            )
                        }
                    }
                    .padding(PremiumDesignTokens.spacing16)
                }
                .allowsHitTesting(viewModel.error == nil)

                // Error overlay
                if let error = viewModel.error {
                    Color.clear
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .overlay {
                            errorOverlay(error)
                        }
                        .transition(.opacity)
                }
            }
            .navigationTitle("Islamic Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(themeColors.textSecondary)
                    }
                    .buttonAccessibility(label: "Close", hint: "Dismisses the Islamic calendar screen")
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Today") {
                        viewModel.selectToday()
                        HapticFeedback.light()
                    }
                    .disabled(viewModel.isToday)
                    .buttonAccessibility(
                        label: "Today",
                        hint: viewModel.isToday ? "Already viewing today" : "Return to today's date"
                    )
                }
            }
        }
        .onAppear {
            viewModel.onAppear()
            withAnimation(AppAnimations.standard) {
                hasAppeared = true
            }
        }
    }

    // MARK: - Subviews

    private var loadingView: some View {
        VStack(spacing: PremiumDesignTokens.spacing16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Loading prayer times...")
                .font(Typography.bodyMedium)
                .foregroundColor(themeColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(PremiumDesignTokens.spacing48)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading prayer times for selected date")
    }

    private func errorOverlay(_ error: AppError) -> some View {
        VStack(spacing: PremiumDesignTokens.spacing16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.red)

            Text(error.localizedDescription)
                .font(Typography.bodyMedium)
                .foregroundColor(themeColors.textPrimary)
                .multilineTextAlignment(.center)

            Button("Retry") {
                viewModel.retry()
                HapticFeedback.medium()
            }
            .font(Typography.titleMedium)
            .padding(.horizontal, PremiumDesignTokens.spacing24)
            .padding(.vertical, PremiumDesignTokens.spacing12)
            .background(themeColors.primary)
            .foregroundColor(.white)
            .cornerRadius(PremiumDesignTokens.cornerRadius12)
        }
        .padding(PremiumDesignTokens.spacing24)
        .background(ColorPalette.surfacePrimary)
        .cornerRadius(PremiumDesignTokens.cornerRadius16)
        .premiumShadow(.level2)
        .padding(PremiumDesignTokens.spacing24)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(error.localizedDescription)")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Helpers

    private var themeColors: ThemeAwareColorPalette {
        ThemeAwareColorPalette(theme: currentTheme)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Islamic Calendar Screen") {
    IslamicCalendarScreen(
        prayerTimeService: MockPrayerTimeService(),
        islamicCalendarService: IslamicCalendarService(),
        locationService: MockLocationService(),
        settingsService: MockSettingsService(),
        onDismiss: { },
        onSettingsTapped: { }
    )
}

#Preview("Islamic Calendar Screen - Dark") {
    IslamicCalendarScreen(
        prayerTimeService: MockPrayerTimeService(),
        islamicCalendarService: IslamicCalendarService(),
        locationService: MockLocationService(),
        settingsService: MockSettingsService(),
        onDismiss: { },
        onSettingsTapped: { }
    )
    .environment(\.currentTheme, .dark)
    .environment(\.colorScheme, .dark)
}
#endif
