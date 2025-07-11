import SwiftUI
import UserNotifications

/// Notification permission request screen
public struct NotificationPermissionScreen: View {
    private let notificationService: any NotificationServiceProtocol
    private let settingsService: any SettingsServiceProtocol
    let onComplete: () -> Void
    
    @State private var isRequestingPermission = false
    
    public init(
        notificationService: any NotificationServiceProtocol,
        settingsService: any SettingsServiceProtocol,
        onComplete: @escaping () -> Void
    ) {
        self.notificationService = notificationService
        self.settingsService = settingsService
        self.onComplete = onComplete
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "bell.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(ColorPalette.primary)
                
                Text("Prayer Reminders")
                    .headlineLarge()
                    .foregroundColor(ColorPalette.textPrimary)
                
                Text("Get notified 10 minutes before each prayer time so you never miss a prayer")
                    .bodyLarge()
                    .foregroundColor(ColorPalette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 60)
            
            Spacer()
            
            // Benefits
            VStack(spacing: 20) {
                NotificationBenefitRow(
                    icon: "clock.badge.fill",
                    title: "Timely Reminders",
                    description: "Never miss a prayer with gentle notifications"
                )
                
                NotificationBenefitRow(
                    icon: "moon.zzz.fill",
                    title: "Respectful Timing",
                    description: "Notifications respect your Do Not Disturb settings"
                )
                
                NotificationBenefitRow(
                    icon: "gear.circle.fill",
                    title: "Fully Customizable",
                    description: "Enable or disable for specific prayers"
                )
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Status and actions
            VStack(spacing: 16) {
                statusView
                actionButtons
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(ColorPalette.backgroundPrimary)
    }
    
    @ViewBuilder
    private var statusView: some View {
        switch notificationService.authorizationStatus {
        case .notDetermined:
            EmptyView()
            
        case .denied:
            VStack(spacing: 8) {
                Image(systemName: "bell.slash.fill")
                    .foregroundColor(ColorPalette.warning)
                    .font(.system(size: 32))
                
                Text("Notifications disabled")
                    .titleMedium()
                    .foregroundColor(ColorPalette.textPrimary)
                
                Text("You can enable notifications in Settings if you change your mind")
                    .bodyMedium()
                    .foregroundColor(ColorPalette.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
        case .authorized, .provisional, .ephemeral:
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(ColorPalette.success)
                    .font(.system(size: 32))
                
                Text("Notifications enabled")
                    .titleMedium()
                    .foregroundColor(ColorPalette.success)
                
                Text("You'll receive prayer reminders 10 minutes before each prayer")
                    .bodyMedium()
                    .foregroundColor(ColorPalette.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
        @unknown default:
            EmptyView()
        }
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        switch notificationService.authorizationStatus {
        case .notDetermined:
            VStack(spacing: 12) {
                if isRequestingPermission {
                    LoadingView.spinner(message: "Requesting permission...")
                } else {
                    CustomButton.primary("Enable Notifications") {
                        requestNotificationPermission()
                    }
                    
                    CustomButton.tertiary("Maybe Later") {
                        completeOnboarding(notificationsEnabled: false)
                    }
                }
            }
            
        case .denied:
            VStack(spacing: 12) {
                CustomButton.primary("Open Settings") {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
                
                CustomButton.secondary("Continue Without Notifications") {
                    completeOnboarding(notificationsEnabled: false)
                }
            }
            
        case .authorized, .provisional, .ephemeral:
            CustomButton.primary("Complete Setup") {
                completeOnboarding(notificationsEnabled: true)
            }
            
        @unknown default:
            CustomButton.tertiary("Continue") {
                completeOnboarding(notificationsEnabled: false)
            }
        }
    }
    
    private func requestNotificationPermission() {
        isRequestingPermission = true
        
        Task {
            do {
                let granted = try await notificationService.requestNotificationPermission()
                await MainActor.run {
                    isRequestingPermission = false
                    if granted {
                        // Permission granted, but don't auto-complete yet
                        // Let user see the success state and tap "Complete Setup"
                    }
                }
            } catch {
                await MainActor.run {
                    isRequestingPermission = false
                    // Handle error if needed
                }
            }
        }
    }
    
    private func completeOnboarding(notificationsEnabled: Bool) {
        settingsService.notificationsEnabled = notificationsEnabled
        settingsService.hasCompletedOnboarding = true
        
        Task {
            try? await settingsService.saveSettings()
            await MainActor.run {
                onComplete()
            }
        }
    }
}

/// Notification benefit row component
private struct NotificationBenefitRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(ColorPalette.primary)
                .frame(width: 32)
            
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

#Preview("Notification Permission Screen") {
    NotificationPermissionScreen(
        notificationService: MockNotificationService(),
        settingsService: MockSettingsService(),
        onComplete: { print("Onboarding complete") }
    )
}
