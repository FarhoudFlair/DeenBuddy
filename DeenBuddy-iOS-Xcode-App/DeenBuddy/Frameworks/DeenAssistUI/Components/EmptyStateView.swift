import SwiftUI

/// Empty state view component for various scenarios
public struct EmptyStateView: View {
    let state: EmptyState
    let onAction: (() -> Void)?

    @Environment(\.currentTheme) private var currentTheme
    @Environment(\.colorScheme) private var colorScheme
    @State private var hasAppeared = false

    private var premiumTokens: PremiumDesignTokens {
        PremiumDesignTokens(theme: currentTheme, colorScheme: colorScheme)
    }

    private var themeColors: ThemeAwareColorPalette {
        ThemeAwareColorPalette(theme: currentTheme)
    }

    public init(state: EmptyState, onAction: (() -> Void)? = nil) {
        self.state = state
        self.onAction = onAction
    }

    public var body: some View {
        VStack(spacing: 32) {
            // Illustration or icon with gradient glow
            VStack(spacing: 16) {
                if let illustration = state.illustration {
                    ZStack {
                        // Gradient glow background
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        themeColors.primary.opacity(0.15),
                                        themeColors.primary.opacity(0.05),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 40,
                                    endRadius: 100
                                )
                            )
                            .frame(width: 160, height: 160)
                            .blur(radius: 8)

                        illustration
                            .font(.system(size: 80))
                            .foregroundStyle(premiumTokens.countdownGradient)
                    }
                    .opacity(hasAppeared ? 1 : 0)
                    .scaleEffect(hasAppeared ? 1 : 0.8)
                    .appAnimation(AppAnimations.staggeredEntry(delay: 0.0), value: hasAppeared)
                } else {
                    ZStack {
                        // Gradient glow background
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        themeColors.primary.opacity(0.15),
                                        themeColors.primary.opacity(0.05),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 30,
                                    endRadius: 80
                                )
                            )
                            .frame(width: 140, height: 140)
                            .blur(radius: 8)

                        Image(systemName: state.iconName)
                            .font(.system(size: 64, weight: .light))
                            .foregroundStyle(premiumTokens.countdownGradient)
                    }
                    .opacity(hasAppeared ? 1 : 0)
                    .scaleEffect(hasAppeared ? 1 : 0.8)
                    .appAnimation(AppAnimations.staggeredEntry(delay: 0.0), value: hasAppeared)
                }
            }

            // Content
            VStack(spacing: 16) {
                Text(state.title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(ColorPalette.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 10)
                    .appAnimation(AppAnimations.staggeredEntry(delay: 0.1), value: hasAppeared)

                Text(state.message)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(ColorPalette.textSecondary)
                    .multilineTextAlignment(.center)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 10)
                    .appAnimation(AppAnimations.staggeredEntry(delay: 0.2), value: hasAppeared)

                if let suggestion = state.suggestion {
                    Text(suggestion)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(ColorPalette.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 10)
                        .appAnimation(AppAnimations.staggeredEntry(delay: 0.3), value: hasAppeared)
                }
            }
            .padding(.horizontal, 32)

            // Action button
            if let actionTitle = state.actionTitle, let onAction = onAction {
                CustomButton.primary(actionTitle) {
                    onAction()
                }
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 10)
                .appAnimation(AppAnimations.staggeredEntry(delay: 0.4), value: hasAppeared)
                .padding(.top, 8)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorPalette.backgroundPrimary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(state.accessibilityLabel)
        .accessibilityHint(state.accessibilityHint)
        .onAppear {
            hasAppeared = true
        }
    }
}

// MARK: - Empty State Types

public enum EmptyState {
    case noPrayerTimes
    case noLocation
    case noNotifications
    case noOfflineContent
    case noSearchResults
    case firstLaunch
    case maintenance
    
    var iconName: String {
        switch self {
        case .noPrayerTimes:
            return "clock.badge.questionmark"
        case .noLocation:
            return "location.slash"
        case .noNotifications:
            return "bell.slash"
        case .noOfflineContent:
            return "icloud.slash"
        case .noSearchResults:
            return "magnifyingglass"
        case .firstLaunch:
            return "hand.wave"
        case .maintenance:
            return "wrench.and.screwdriver"
        }
    }
    
    var illustration: Image? {
        switch self {
        case .firstLaunch:
            return Image(systemName: "moon.stars")
        default:
            return nil
        }
    }
    
    var title: String {
        switch self {
        case .noPrayerTimes:
            return "No Prayer Times Available"
        case .noLocation:
            return "Location Not Set"
        case .noNotifications:
            return "No Notifications Scheduled"
        case .noOfflineContent:
            return "No Offline Content"
        case .noSearchResults:
            return "No Results Found"
        case .firstLaunch:
            return "Welcome to DeenBuddy"
        case .maintenance:
            return "Under Maintenance"
        }
    }
    
    var message: String {
        switch self {
        case .noPrayerTimes:
            return "We couldn't load prayer times for your location. Please check your settings and try again."
        case .noLocation:
            return "Set your location to get accurate prayer times and Qibla direction."
        case .noNotifications:
            return "Enable notifications to receive prayer time reminders."
        case .noOfflineContent:
            return "Download prayer guides to access them without an internet connection."
        case .noSearchResults:
            return "We couldn't find any results matching your search. Try different keywords."
        case .firstLaunch:
            return "Your companion for daily worship. Get started by setting up your location and preferences."
        case .maintenance:
            return "We're making improvements to serve you better. Please try again later."
        }
    }
    
    var suggestion: String? {
        switch self {
        case .noPrayerTimes:
            return "Check your internet connection and location permissions."
        case .noLocation:
            return "You can set your location automatically or enter your city manually."
        case .noNotifications:
            return "Go to Settings to enable prayer reminders."
        case .noOfflineContent:
            return "Browse available guides and tap 'Make Available Offline'."
        case .noSearchResults:
            return "Try searching for a different city or check your spelling."
        case .firstLaunch:
            return "The setup process takes less than a minute."
        case .maintenance:
            return "Follow us on social media for updates."
        }
    }
    
    var actionTitle: String? {
        switch self {
        case .noPrayerTimes:
            return "Retry"
        case .noLocation:
            return "Set Location"
        case .noNotifications:
            return "Enable Notifications"
        case .noOfflineContent:
            return "Browse Guides"
        case .noSearchResults:
            return "Try Again"
        case .firstLaunch:
            return "Get Started"
        case .maintenance:
            return "Check Status"
        }
    }
    
    var accessibilityLabel: String {
        return "\(title). \(message)"
    }
    
    var accessibilityHint: String {
        if actionTitle != nil {
            return "Double tap to \(actionTitle!.lowercased())"
        }
        return ""
    }
}

// MARK: - Specialized Empty State Views

public struct NoPrayerTimesView: View {
    let onRetry: () -> Void
    let onSetLocation: () -> Void
    
    public init(onRetry: @escaping () -> Void, onSetLocation: @escaping () -> Void) {
        self.onRetry = onRetry
        self.onSetLocation = onSetLocation
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            EmptyStateView(state: .noPrayerTimes, onAction: onRetry)
            
            CustomButton.secondary("Set Location") {
                onSetLocation()
            }
        }
    }
}

public struct FirstLaunchView: View {
    let onGetStarted: () -> Void
    
    public init(onGetStarted: @escaping () -> Void) {
        self.onGetStarted = onGetStarted
    }
    
    public var body: some View {
        EmptyStateView(state: .firstLaunch, onAction: onGetStarted)
    }
}

// MARK: - Empty State Container

public struct EmptyStateContainer<Content: View>: View {
    let isEmpty: Bool
    let emptyState: EmptyState
    let onAction: (() -> Void)?
    @ViewBuilder let content: () -> Content
    
    public init(
        isEmpty: Bool,
        emptyState: EmptyState,
        onAction: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.isEmpty = isEmpty
        self.emptyState = emptyState
        self.onAction = onAction
        self.content = content
    }
    
    public var body: some View {
        Group {
            if isEmpty {
                EmptyStateView(state: emptyState, onAction: onAction)
            } else {
                content()
            }
        }
    }
}

// MARK: - Preview

#Preview("Empty States") {
    VStack(spacing: 20) {
        EmptyStateView(state: .noPrayerTimes, onAction: {})
        EmptyStateView(state: .firstLaunch, onAction: {})
        EmptyStateView(state: .noLocation, onAction: {})
    }
    .background(ColorPalette.backgroundPrimary)
}
