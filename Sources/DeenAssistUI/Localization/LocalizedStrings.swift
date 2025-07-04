import Foundation

/// Localization support for the Deen Assist app
public struct LocalizedStrings {
    
    // MARK: - App Name and Branding
    
    public static let appName = NSLocalizedString(
        "app.name",
        value: "Deen Assist",
        comment: "The name of the app"
    )
    
    public static let appTagline = NSLocalizedString(
        "app.tagline",
        value: "Your companion for daily worship",
        comment: "App tagline displayed on welcome screen"
    )
    
    // MARK: - Onboarding
    
    public static let welcomeTitle = NSLocalizedString(
        "onboarding.welcome.title",
        value: "Welcome to Deen Assist",
        comment: "Title for welcome screen"
    )
    
    public static let welcomeMessage = NSLocalizedString(
        "onboarding.welcome.message",
        value: "Your companion for daily worship",
        comment: "Message for welcome screen"
    )
    
    public static let getStarted = NSLocalizedString(
        "onboarding.get_started",
        value: "Get Started",
        comment: "Button to start onboarding"
    )
    
    public static let locationPermissionTitle = NSLocalizedString(
        "onboarding.location.title",
        value: "Location Access",
        comment: "Title for location permission screen"
    )
    
    public static let locationPermissionMessage = NSLocalizedString(
        "onboarding.location.message",
        value: "We need your location to provide accurate prayer times for your area",
        comment: "Message explaining why location permission is needed"
    )
    
    public static let allowLocationAccess = NSLocalizedString(
        "onboarding.location.allow",
        value: "Allow Location Access",
        comment: "Button to allow location access"
    )
    
    public static let enterCityManually = NSLocalizedString(
        "onboarding.location.manual",
        value: "Enter City Manually",
        comment: "Button to enter city manually"
    )
    
    public static let calculationMethodTitle = NSLocalizedString(
        "onboarding.calculation.title",
        value: "Prayer Calculation",
        comment: "Title for calculation method screen"
    )
    
    public static let calculationMethodMessage = NSLocalizedString(
        "onboarding.calculation.message",
        value: "Choose the calculation method and madhab that matches your region or preference",
        comment: "Message explaining calculation method selection"
    )
    
    public static let notificationPermissionTitle = NSLocalizedString(
        "onboarding.notification.title",
        value: "Prayer Reminders",
        comment: "Title for notification permission screen"
    )
    
    public static let notificationPermissionMessage = NSLocalizedString(
        "onboarding.notification.message",
        value: "Get notified 10 minutes before each prayer time so you never miss a prayer",
        comment: "Message explaining notification benefits"
    )
    
    public static let enableNotifications = NSLocalizedString(
        "onboarding.notification.enable",
        value: "Enable Notifications",
        comment: "Button to enable notifications"
    )
    
    public static let maybeLater = NSLocalizedString(
        "onboarding.maybe_later",
        value: "Maybe Later",
        comment: "Button to skip optional steps"
    )
    
    // MARK: - Prayer Names
    
    public static let fajr = NSLocalizedString(
        "prayer.fajr",
        value: "Fajr",
        comment: "Name of Fajr prayer"
    )
    
    public static let dhuhr = NSLocalizedString(
        "prayer.dhuhr",
        value: "Dhuhr",
        comment: "Name of Dhuhr prayer"
    )
    
    public static let asr = NSLocalizedString(
        "prayer.asr",
        value: "Asr",
        comment: "Name of Asr prayer"
    )
    
    public static let maghrib = NSLocalizedString(
        "prayer.maghrib",
        value: "Maghrib",
        comment: "Name of Maghrib prayer"
    )
    
    public static let isha = NSLocalizedString(
        "prayer.isha",
        value: "Isha",
        comment: "Name of Isha prayer"
    )
    
    // MARK: - Home Screen
    
    public static let nextPrayer = NSLocalizedString(
        "home.next_prayer",
        value: "Next Prayer",
        comment: "Label for next prayer section"
    )
    
    public static let timeRemaining = NSLocalizedString(
        "home.time_remaining",
        value: "Time Remaining",
        comment: "Label for countdown timer"
    )
    
    public static let todaysPrayers = NSLocalizedString(
        "home.todays_prayers",
        value: "Today's Prayers",
        comment: "Section title for today's prayer times"
    )
    
    public static let quickActions = NSLocalizedString(
        "home.quick_actions",
        value: "Quick Actions",
        comment: "Section title for quick action buttons"
    )
    
    public static let qiblaCompass = NSLocalizedString(
        "home.qibla_compass",
        value: "Qibla Compass",
        comment: "Title for qibla compass feature"
    )
    
    public static let prayerGuides = NSLocalizedString(
        "home.prayer_guides",
        value: "Prayer Guides",
        comment: "Title for prayer guides feature"
    )
    
    // MARK: - Settings
    
    public static let settings = NSLocalizedString(
        "settings.title",
        value: "Settings",
        comment: "Title for settings screen"
    )
    
    public static let prayerSettings = NSLocalizedString(
        "settings.prayer_settings",
        value: "Prayer Settings",
        comment: "Section title for prayer settings"
    )
    
    public static let calculationMethod = NSLocalizedString(
        "settings.calculation_method",
        value: "Calculation Method",
        comment: "Label for calculation method setting"
    )
    
    public static let madhab = NSLocalizedString(
        "settings.madhab",
        value: "Madhab (Asr Time)",
        comment: "Label for madhab setting"
    )
    
    public static let notifications = NSLocalizedString(
        "settings.notifications",
        value: "Notifications",
        comment: "Section title for notification settings"
    )
    
    public static let prayerReminders = NSLocalizedString(
        "settings.prayer_reminders",
        value: "Prayer Reminders",
        comment: "Label for prayer reminder setting"
    )
    
    public static let appearance = NSLocalizedString(
        "settings.appearance",
        value: "Appearance",
        comment: "Section title for appearance settings"
    )
    
    public static let theme = NSLocalizedString(
        "settings.theme",
        value: "Theme",
        comment: "Label for theme setting"
    )
    
    public static let about = NSLocalizedString(
        "settings.about",
        value: "About",
        comment: "Section title for about information"
    )
    
    public static let version = NSLocalizedString(
        "settings.version",
        value: "Version",
        comment: "Label for app version"
    )
    
    // MARK: - Common Actions
    
    public static let done = NSLocalizedString(
        "action.done",
        value: "Done",
        comment: "Done button"
    )
    
    public static let cancel = NSLocalizedString(
        "action.cancel",
        value: "Cancel",
        comment: "Cancel button"
    )
    
    public static let save = NSLocalizedString(
        "action.save",
        value: "Save",
        comment: "Save button"
    )
    
    public static let retry = NSLocalizedString(
        "action.retry",
        value: "Retry",
        comment: "Retry button"
    )
    
    public static let skip = NSLocalizedString(
        "action.skip",
        value: "Skip",
        comment: "Skip button"
    )
    
    public static let `continue` = NSLocalizedString(
        "action.continue",
        value: "Continue",
        comment: "Continue button"
    )
    
    // MARK: - Error Messages
    
    public static let networkError = NSLocalizedString(
        "error.network",
        value: "Connection Error",
        comment: "Network error title"
    )
    
    public static let locationError = NSLocalizedString(
        "error.location",
        value: "Location Unavailable",
        comment: "Location error title"
    )
    
    public static let permissionDenied = NSLocalizedString(
        "error.permission_denied",
        value: "Permission Required",
        comment: "Permission denied error title"
    )
    
    public static let unknownError = NSLocalizedString(
        "error.unknown",
        value: "Something Went Wrong",
        comment: "Unknown error title"
    )
    
    // MARK: - Loading Messages
    
    public static let loading = NSLocalizedString(
        "loading.default",
        value: "Loading...",
        comment: "Default loading message"
    )
    
    public static let calculatingPrayerTimes = NSLocalizedString(
        "loading.calculating_prayer_times",
        value: "Calculating prayer times...",
        comment: "Loading message for prayer time calculation"
    )
    
    public static let preparingSchedule = NSLocalizedString(
        "loading.preparing_schedule",
        value: "Preparing your prayer schedule...",
        comment: "Loading message for schedule preparation"
    )
    
    // MARK: - Accessibility
    
    public static let accessibilityPrayerTime = NSLocalizedString(
        "accessibility.prayer_time",
        value: "%@ prayer at %@",
        comment: "Accessibility label for prayer time. First %@ is prayer name, second %@ is time"
    )
    
    public static let accessibilityNextPrayer = NSLocalizedString(
        "accessibility.next_prayer",
        value: "Next prayer: %@ in %@",
        comment: "Accessibility label for next prayer. First %@ is prayer name, second %@ is time remaining"
    )
    
    public static let accessibilityButton = NSLocalizedString(
        "accessibility.button",
        value: "Double tap to activate",
        comment: "Accessibility hint for buttons"
    )
}

// MARK: - Localization Helper

public extension String {
    /// Get localized string with fallback to the string itself
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
    
    /// Get localized string with arguments
    func localized(with arguments: CVarArg...) -> String {
        return String(format: NSLocalizedString(self, comment: ""), arguments: arguments)
    }
}

// MARK: - Prayer Name Localization

public extension PrayerType {
    var localizedDisplayName: String {
        switch self {
        case .fajr:
            return LocalizedStrings.fajr
        case .dhuhr:
            return LocalizedStrings.dhuhr
        case .asr:
            return LocalizedStrings.asr
        case .maghrib:
            return LocalizedStrings.maghrib
        case .isha:
            return LocalizedStrings.isha
        }
    }
}

// MARK: - Theme Mode Localization

public extension ThemeMode {
    var localizedDisplayName: String {
        switch self {
        case .dark:
            return NSLocalizedString("theme.dark", value: "Dark Theme", comment: "Dark theme name")
        case .islamicGreen:
            return NSLocalizedString("theme.islamicGreen", value: "Islamic Green Theme", comment: "Islamic green theme name")
        }
    }
}
