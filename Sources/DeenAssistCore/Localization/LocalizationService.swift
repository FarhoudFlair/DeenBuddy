import Foundation
import Combine

/// Service for managing app localization and internationalization
@MainActor
public class LocalizationService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var currentLanguage: SupportedLanguage = .english
    @Published public var isRTLLanguage = false
    @Published public var availableLanguages: [SupportedLanguage] = []
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    private var bundle: Bundle = Bundle.main
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Cache Keys
    
    private enum CacheKeys {
        static let selectedLanguage = "DeenAssist.Localization.SelectedLanguage"
    }
    
    // MARK: - Singleton
    
    public static let shared = LocalizationService()
    
    private init() {
        setupAvailableLanguages()
        loadSelectedLanguage()
        updateRTLStatus()
    }
    
    // MARK: - Public Methods
    
    /// Get localized string for key
    public func localizedString(for key: String, comment: String = "") -> String {
        return NSLocalizedString(key, bundle: bundle, comment: comment)
    }
    
    /// Get localized string with arguments
    public func localizedString(for key: String, arguments: CVarArg...) -> String {
        let format = localizedString(for: key)
        return String(format: format, arguments: arguments)
    }
    
    /// Change app language
    public func setLanguage(_ language: SupportedLanguage) {
        currentLanguage = language
        isRTLLanguage = language.isRTL
        
        // Save preference
        userDefaults.set(language.rawValue, forKey: CacheKeys.selectedLanguage)
        
        // Update bundle for localized strings
        updateBundle()
        
        // Notify about language change
        NotificationCenter.default.post(name: .languageChanged, object: language)
        
        print("🌍 Language changed to: \(language.displayName)")
        
        // Track analytics
        AnalyticsService.shared.trackUserAction("language_changed", parameters: ["language": language.rawValue])
    }
    
    /// Get formatted date string
    public func formatDate(_ date: Date, style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.locale = currentLanguage.locale
        return formatter.string(from: date)
    }
    
    /// Get formatted time string
    public func formatTime(_ date: Date, style: DateFormatter.Style = .short) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = style
        formatter.locale = currentLanguage.locale
        return formatter.string(from: date)
    }
    
    /// Get formatted number string
    public func formatNumber(_ number: NSNumber, style: NumberFormatter.Style = .decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = style
        formatter.locale = currentLanguage.locale
        return formatter.string(from: number) ?? number.stringValue
    }
    
    /// Get prayer name in current language
    public func prayerName(for prayer: Prayer) -> String {
        return localizedString(for: "prayer.\(prayer.rawValue)")
    }
    
    /// Get calculation method name in current language
    public func calculationMethodName(for method: CalculationMethod) -> String {
        return localizedString(for: "calculation_method.\(method.rawValue)")
    }
    
    /// Get madhab name in current language
    public func madhabName(for madhab: Madhab) -> String {
        return localizedString(for: "madhab.\(madhab.rawValue)")
    }
    
    /// Check if localization is available for language
    public func isLocalizationAvailable(for language: SupportedLanguage) -> Bool {
        return availableLanguages.contains(language)
    }
    
    /// Get device's preferred language
    public var devicePreferredLanguage: SupportedLanguage {
        let preferredLanguages = Locale.preferredLanguages
        
        for languageCode in preferredLanguages {
            if let language = SupportedLanguage.from(languageCode: languageCode) {
                return language
            }
        }
        
        return .english // Default fallback
    }
    
    // MARK: - Private Methods
    
    private func setupAvailableLanguages() {
        // Start with English as base
        availableLanguages = [.english]
        
        // Check for available localizations in bundle
        let bundleLocalizations = Bundle.main.localizations
        
        for localization in bundleLocalizations {
            if let language = SupportedLanguage.from(languageCode: localization),
               !availableLanguages.contains(language) {
                availableLanguages.append(language)
            }
        }
        
        print("🌍 Available languages: \(availableLanguages.map { $0.displayName }.joined(separator: ", "))")
    }
    
    private func loadSelectedLanguage() {
        if let savedLanguage = userDefaults.string(forKey: CacheKeys.selectedLanguage),
           let language = SupportedLanguage(rawValue: savedLanguage) {
            currentLanguage = language
        } else {
            // Use device preferred language if available
            currentLanguage = devicePreferredLanguage
        }
        
        updateBundle()
    }
    
    private func updateRTLStatus() {
        isRTLLanguage = currentLanguage.isRTL
    }
    
    private func updateBundle() {
        if let path = Bundle.main.path(forResource: currentLanguage.languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            self.bundle = bundle
        } else {
            self.bundle = Bundle.main
        }
    }
}

// MARK: - Supported Languages

public enum SupportedLanguage: String, CaseIterable {
    case english = "en"
    case arabic = "ar"
    case urdu = "ur"
    case turkish = "tr"
    case indonesian = "id"
    case malay = "ms"
    case french = "fr"
    case german = "de"
    case spanish = "es"
    
    public var displayName: String {
        switch self {
        case .english: return "English"
        case .arabic: return "العربية"
        case .urdu: return "اردو"
        case .turkish: return "Türkçe"
        case .indonesian: return "Bahasa Indonesia"
        case .malay: return "Bahasa Melayu"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .spanish: return "Español"
        }
    }
    
    public var languageCode: String {
        return rawValue
    }
    
    public var locale: Locale {
        return Locale(identifier: languageCode)
    }
    
    public var isRTL: Bool {
        switch self {
        case .arabic, .urdu:
            return true
        default:
            return false
        }
    }
    
    public var flag: String {
        switch self {
        case .english: return "🇺🇸"
        case .arabic: return "🇸🇦"
        case .urdu: return "🇵🇰"
        case .turkish: return "🇹🇷"
        case .indonesian: return "🇮🇩"
        case .malay: return "🇲🇾"
        case .french: return "🇫🇷"
        case .german: return "🇩🇪"
        case .spanish: return "🇪🇸"
        }
    }
    
    public static func from(languageCode: String) -> SupportedLanguage? {
        // Handle language codes with region (e.g., "en-US" -> "en")
        let baseLanguageCode = String(languageCode.prefix(2))
        return SupportedLanguage(rawValue: baseLanguageCode)
    }
}

// MARK: - Localization Keys

public struct LocalizationKeys {
    
    // MARK: - General
    public static let appName = "app.name"
    public static let ok = "general.ok"
    public static let cancel = "general.cancel"
    public static let done = "general.done"
    public static let save = "general.save"
    public static let delete = "general.delete"
    public static let edit = "general.edit"
    public static let loading = "general.loading"
    public static let error = "general.error"
    public static let retry = "general.retry"
    
    // MARK: - Prayers
    public static let fajr = "prayer.fajr"
    public static let dhuhr = "prayer.dhuhr"
    public static let asr = "prayer.asr"
    public static let maghrib = "prayer.maghrib"
    public static let isha = "prayer.isha"
    
    // MARK: - Navigation
    public static let home = "navigation.home"
    public static let prayerTimes = "navigation.prayer_times"
    public static let qibla = "navigation.qibla"
    public static let guides = "navigation.guides"
    public static let settings = "navigation.settings"
    
    // MARK: - Onboarding
    public static let welcome = "onboarding.welcome"
    public static let getStarted = "onboarding.get_started"
    public static let skipForNow = "onboarding.skip_for_now"
    public static let locationPermission = "onboarding.location_permission"
    public static let notificationPermission = "onboarding.notification_permission"
    
    // MARK: - Settings
    public static let calculationMethod = "settings.calculation_method"
    public static let madhab = "settings.madhab"
    public static let notifications = "settings.notifications"
    public static let language = "settings.language"
    public static let theme = "settings.theme"
    public static let privacy = "settings.privacy"
    
    // MARK: - Errors
    public static let locationUnavailable = "error.location_unavailable"
    public static let networkError = "error.network_error"
    public static let permissionDenied = "error.permission_denied"
    public static let calculationFailed = "error.calculation_failed"
}

// MARK: - String Extensions

public extension String {
    /// Get localized version of this string
    var localized: String {
        return LocalizationService.shared.localizedString(for: self)
    }
    
    /// Get localized version with arguments
    func localized(with arguments: CVarArg...) -> String {
        return LocalizationService.shared.localizedString(for: self, arguments: arguments)
    }
}

// MARK: - Notification Extensions

public extension Notification.Name {
    static let languageChanged = Notification.Name("languageChanged")
}

// MARK: - SwiftUI Extensions

public extension View {
    /// Apply RTL layout if needed
    func localizedLayout() -> some View {
        let service = LocalizationService.shared
        
        return self
            .environment(\.layoutDirection, service.isRTLLanguage ? .rightToLeft : .leftToRight)
    }
    
    /// Apply localized text alignment
    func localizedTextAlignment() -> some View {
        let service = LocalizationService.shared
        
        return self
            .multilineTextAlignment(service.isRTLLanguage ? .trailing : .leading)
    }
}
