import Foundation
import Combine

// MARK: - Localization Service

/// Service for managing app localization and translations
@MainActor
public class LocalizationService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var currentLanguage: AppLanguage
    @Published public var isLoading = false
    @Published public var error: LocalizationError?
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    private var translations: [String: [String: String]] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Cache Keys
    
    private enum CacheKeys {
        static let currentLanguage = "DeenAssist.CurrentLanguage"
        static let translations = "DeenAssist.Translations"
    }
    
    // MARK: - Initialization
    
    public init() {
        self.currentLanguage = Self.loadCurrentLanguage()
        loadTranslations()
        setupSystemLanguageObserver()
    }
    
    // MARK: - Public Methods
    
    /// Change the current language
    public func changeLanguage(_ language: AppLanguage) {
        currentLanguage = language
        saveCurrentLanguage()
        loadTranslations()
        
        // Update system locale
        updateSystemLocale()
        
        // Notify about language change
        NotificationCenter.default.post(name: .languageChanged, object: language)
    }
    
    /// Get localized string for a key
    public func localizedString(for key: LocalizationKey, defaultValue: String? = nil) -> String {
        return localizedString(for: key.key, defaultValue: defaultValue)
    }
    
    /// Get localized string for a key
    public func localizedString(for key: String, defaultValue: String? = nil) -> String {
        let languageTranslations = translations[currentLanguage.id] ?? [:]
        
        if let translation = languageTranslations[key] {
            return translation
        }
        
        // Fallback to English if available
        if currentLanguage.id != "en", let englishTranslations = translations["en"] {
            if let englishTranslation = englishTranslations[key] {
                return englishTranslation
            }
        }
        
        // Return default value or key
        return defaultValue ?? key
    }
    
    /// Get localized prayer name
    public func localizedPrayerName(for prayer: Prayer) -> String {
        return currentLanguage.prayerNames.name(for: prayer)
    }
    
    /// Get localized number string
    public func localizedNumber(_ number: Int) -> String {
        return currentLanguage.numberFormat.format(number)
    }
    
    /// Get localized date string
    public func localizedDate(_ date: Date, style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.locale = currentLanguage.locale
        formatter.dateStyle = style
        
        // Use appropriate calendar
        switch currentLanguage.calendarType {
        case .gregorian:
            formatter.calendar = Calendar(identifier: .gregorian)
        case .hijri:
            formatter.calendar = Calendar(identifier: .islamicCivil)
        case .persian:
            formatter.calendar = Calendar(identifier: .persian)
        case .turkish:
            formatter.calendar = Calendar(identifier: .gregorian)
        }
        
        return formatter.string(from: date)
    }
    
    /// Get localized time string
    public func localizedTime(_ date: Date, style: DateFormatter.Style = .short) -> String {
        let formatter = DateFormatter()
        formatter.locale = currentLanguage.locale
        formatter.timeStyle = style
        
        let timeString = formatter.string(from: date)
        
        // Apply number format if needed
        if currentLanguage.numberFormat != .western {
            return applyNumberFormat(timeString)
        }
        
        return timeString
    }
    
    /// Get RTL-aware text alignment
    public var textAlignment: NSTextAlignment {
        return currentLanguage.isRTL ? .right : .left
    }
    
    /// Get layout direction
    public var layoutDirection: LayoutDirection {
        return currentLanguage.isRTL ? .rightToLeft : .leftToRight
    }
    
    /// Check if current language is RTL
    public var isRTL: Bool {
        return currentLanguage.isRTL
    }
    
    /// Get available languages for current region
    public func getAvailableLanguages() -> [AppLanguage] {
        return AppLanguage.supportedLanguages
    }
    
    /// Get languages for specific region
    public func getLanguages(for region: LanguageRegion) -> [AppLanguage] {
        return AppLanguage.getLanguages(for: region)
    }
    
    /// Auto-detect best language based on system settings
    public func autoDetectLanguage() -> AppLanguage {
        return AppLanguage.systemPreferredLanguage
    }
    
    /// Refresh translations from remote source
    public func refreshTranslations() async {
        isLoading = true
        error = nil
        
        do {
            // In a real implementation, this would fetch from a remote service
            // For now, we'll reload local translations
            await loadRemoteTranslations()
            loadTranslations()
        } catch {
            self.error = error as? LocalizationError ?? .translationLoadFailed
        }
        
        isLoading = false
    }
    
    // MARK: - Private Methods
    
    private static func loadCurrentLanguage() -> AppLanguage {
        guard let data = UserDefaults.standard.data(forKey: CacheKeys.currentLanguage),
              let savedLanguage = try? JSONDecoder().decode(AppLanguage.self, from: data) else {
            return AppLanguage.systemPreferredLanguage
        }
        
        return savedLanguage
    }
    
    private func saveCurrentLanguage() {
        if let data = try? JSONEncoder().encode(currentLanguage) {
            userDefaults.set(data, forKey: CacheKeys.currentLanguage)
        }
    }
    
    private func loadTranslations() {
        // Load cached translations
        if let data = userDefaults.data(forKey: CacheKeys.translations),
           let cached = try? JSONDecoder().decode([String: [String: String]].self, from: data) {
            translations = cached
        }
        
        // Load default translations
        loadDefaultTranslations()
    }
    
    private func loadDefaultTranslations() {
        let languageCodes = ["en", "ar", "fr", "es", "ur"]
        
        for code in languageCodes {
            guard let url = Bundle.main.url(forResource: "Localizable_\(code)", withExtension: "json", subdirectory: "Resources"),
                  let data = try? Data(contentsOf: url),
                  let dictionary = try? JSONDecoder().decode([String: String].self, from: data) else {
                continue
            }
            translations[code] = dictionary
        }
        
        saveTranslations()
    }
    
    private func saveTranslations() {
        if let data = try? JSONEncoder().encode(translations) {
            userDefaults.set(data, forKey: CacheKeys.translations)
        }
    }
    
    private func loadRemoteTranslations() async {
        // In a real implementation, this would fetch from a remote service
        // For now, we'll simulate loading
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
    }
    
    private func updateSystemLocale() {
        // Update system locale if needed
        let locale = Locale(identifier: currentLanguage.localeIdentifier)
        
        // This would require app restart to take full effect
        // For immediate UI updates, we rely on the published currentLanguage
    }
    
    private func setupSystemLanguageObserver() {
        NotificationCenter.default.publisher(for: NSLocale.currentLocaleDidChangeNotification)
            .sink { [weak self] _ in
                self?.handleSystemLanguageChange()
            }
            .store(in: &cancellables)
    }
    
    private func handleSystemLanguageChange() {
        // Optionally update to system language if user hasn't manually set one
        // This depends on app policy
    }
    
    private func applyNumberFormat(_ text: String) -> String {
        var result = text
        
        switch currentLanguage.numberFormat {
        case .western:
            break // No change needed
        case .arabic:
            result = result.applyArabicNumerals()
        case .persian:
            result = result.applyPersianNumerals()
        case .urdu:
            result = result.applyUrduNumerals()
        }
        
        return result
    }
}

// MARK: - Layout Direction

public enum LayoutDirection {
    case leftToRight
    case rightToLeft
}

// MARK: - Localization Error

public enum LocalizationError: Error, LocalizedError {
    case languageNotSupported
    case translationLoadFailed
    case invalidLocale
    
    public var errorDescription: String? {
        switch self {
        case .languageNotSupported:
            return "Language not supported"
        case .translationLoadFailed:
            return "Failed to load translations"
        case .invalidLocale:
            return "Invalid locale"
        }
    }
}

// MARK: - Notification Names

public extension Notification.Name {
    static let languageChanged = Notification.Name("LanguageChanged")
}

// MARK: - Convenience Extensions

public extension String {
    /// Get localized string using the shared localization service
    var localized: String {
        // In a real implementation, this would use a shared instance
        return self
    }
    
    /// Get localized string with arguments
    func localized(_ arguments: CVarArg...) -> String {
        return String(format: self.localized, arguments)
    }
}

// MARK: - SwiftUI Extensions

#if canImport(SwiftUI)
import SwiftUI

public extension View {
    /// Apply RTL layout if needed
    func rtlAware(_ localizationService: LocalizationService) -> some View {
        self.environment(\.layoutDirection, localizationService.isRTL ? .rightToLeft : .leftToRight)
    }
    
    /// Apply localized text alignment
    func localizedTextAlignment(_ localizationService: LocalizationService) -> some View {
        self.multilineTextAlignment(localizationService.isRTL ? .trailing : .leading)
    }
    
    /// Apply localized frame alignment
    func localizedFrameAlignment(_ localizationService: LocalizationService) -> some View {
        self.frame(maxWidth: .infinity, alignment: localizationService.isRTL ? .trailing : .leading)
    }
}

/// Environment key for localization service
struct LocalizationServiceKey: EnvironmentKey {
    static let defaultValue: LocalizationService? = nil
}

public extension EnvironmentValues {
    var localizationService: LocalizationService? {
        get { self[LocalizationServiceKey.self] }
        set { self[LocalizationServiceKey.self] = newValue }
    }
}

/// View modifier for applying localized strings
struct LocalizedText: ViewModifier {
    let key: String
    @Environment(\.localizationService) private var localizationService
    
    func body(content: Content) -> some View {
        if let service = localizationService {
            Text(service.localizedString(for: key))
        } else {
            content
        }
    }
}

public extension Text {
    /// Create localized text
    static func localized(_ key: String) -> Text {
        Text(key) // This will be replaced by the modifier
    }
    
    /// Create localized text with localization key
    static func localized(_ key: LocalizationKey) -> Text {
        Text(key.rawValue)
    }
}

public extension View {
    /// Apply localized text modifier
    func localized(_ key: String) -> some View {
        self.modifier(LocalizedText(key: key))
    }
}
#endif