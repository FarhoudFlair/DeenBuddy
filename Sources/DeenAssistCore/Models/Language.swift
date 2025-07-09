import Foundation

// MARK: - Language Models

/// Represents a supported language in the app
public struct AppLanguage: Codable, Identifiable, Equatable, Hashable {
    public let id: String
    public let code: String
    public let name: String
    public let nativeName: String
    public let direction: TextDirection
    public let region: LanguageRegion
    public let dialect: String?
    public let isRTL: Bool
    public let calendarType: CalendarType
    public let numberFormat: NumberFormat
    public let dateFormat: DateFormat
    public let prayerNames: PrayerNames
    public let isDefault: Bool
    
    public init(
        id: String,
        code: String,
        name: String,
        nativeName: String,
        direction: TextDirection,
        region: LanguageRegion,
        dialect: String? = nil,
        calendarType: CalendarType = .gregorian,
        numberFormat: NumberFormat = .western,
        dateFormat: DateFormat = .standard,
        prayerNames: PrayerNames,
        isDefault: Bool = false
    ) {
        self.id = id
        self.code = code
        self.name = name
        self.nativeName = nativeName
        self.direction = direction
        self.region = region
        self.dialect = dialect
        self.isRTL = direction == .rightToLeft
        self.calendarType = calendarType
        self.numberFormat = numberFormat
        self.dateFormat = dateFormat
        self.prayerNames = prayerNames
        self.isDefault = isDefault
    }
    
    /// Display name for the language
    public var displayName: String {
        if let dialect = dialect {
            return "\(nativeName) (\(dialect))"
        }
        return nativeName
    }
    
    /// Locale identifier
    public var localeIdentifier: String {
        return code
    }
    
    /// Get locale object
    public var locale: Locale {
        return Locale(identifier: localeIdentifier)
    }
}

/// Text direction for different languages
public enum TextDirection: String, Codable, CaseIterable {
    case leftToRight = "ltr"
    case rightToLeft = "rtl"
    
    public var displayName: String {
        switch self {
        case .leftToRight: return "Left to Right"
        case .rightToLeft: return "Right to Left"
        }
    }
}

/// Language regions
public enum LanguageRegion: String, Codable, CaseIterable {
    case middleEast = "middle_east"
    case northAfrica = "north_africa"
    case southAsia = "south_asia"
    case southeastAsia = "southeast_asia"
    case centralAsia = "central_asia"
    case europe = "europe"
    case northAmerica = "north_america"
    case subSaharanAfrica = "sub_saharan_africa"
    
    public var displayName: String {
        switch self {
        case .middleEast: return "Middle East"
        case .northAfrica: return "North Africa"
        case .southAsia: return "South Asia"
        case .southeastAsia: return "Southeast Asia"
        case .centralAsia: return "Central Asia"
        case .europe: return "Europe"
        case .northAmerica: return "North America"
        case .subSaharanAfrica: return "Sub-Saharan Africa"
        }
    }
}

/// Calendar types used in different regions
public enum CalendarType: String, Codable, CaseIterable {
    case gregorian = "gregorian"
    case hijri = "hijri"
    case persian = "persian"
    case turkish = "turkish"
    
    public var displayName: String {
        switch self {
        case .gregorian: return "Gregorian"
        case .hijri: return "Hijri"
        case .persian: return "Persian"
        case .turkish: return "Turkish"
        }
    }
}

/// Number formatting systems
public enum NumberFormat: String, Codable, CaseIterable {
    case western = "western"
    case arabic = "arabic"
    case persian = "persian"
    case urdu = "urdu"
    
    public var displayName: String {
        switch self {
        case .western: return "Western (0-9)"
        case .arabic: return "Arabic (٠-٩)"
        case .persian: return "Persian (۰-۹)"
        case .urdu: return "Urdu (۰-۹)"
        }
    }
    
    /// Convert western numerals to localized format
    public func format(_ number: Int) -> String {
        switch self {
        case .western:
            return "\(number)"
        case .arabic:
            return "\(number)".applyArabicNumerals()
        case .persian:
            return "\(number)".applyPersianNumerals()
        case .urdu:
            return "\(number)".applyUrduNumerals()
        }
    }
}

/// Date formatting preferences
public enum DateFormat: String, Codable, CaseIterable {
    case standard = "standard"
    case islamic = "islamic"
    case persian = "persian"
    
    public var displayName: String {
        switch self {
        case .standard: return "Standard"
        case .islamic: return "Islamic"
        case .persian: return "Persian"
        }
    }
}

/// Prayer names in different languages
public struct PrayerNames: Codable, Equatable, Hashable {
    public let fajr: String
    public let dhuhr: String
    public let asr: String
    public let maghrib: String
    public let isha: String
    
    public init(fajr: String, dhuhr: String, asr: String, maghrib: String, isha: String) {
        self.fajr = fajr
        self.dhuhr = dhuhr
        self.asr = asr
        self.maghrib = maghrib
        self.isha = isha
    }
    
    /// Get prayer name by prayer type
    public func name(for prayer: Prayer) -> String {
        switch prayer {
        case .fajr: return fajr
        case .dhuhr: return dhuhr
        case .asr: return asr
        case .maghrib: return maghrib
        case .isha: return isha
        }
    }
}

// MARK: - Supported Languages

public extension AppLanguage {
    /// All supported languages
    static let supportedLanguages: [AppLanguage] = [
        // English (Default)
        AppLanguage(
            id: "en",
            code: "en",
            name: "English",
            nativeName: "English",
            direction: .leftToRight,
            region: .northAmerica,
            prayerNames: PrayerNames(
                fajr: "Fajr",
                dhuhr: "Dhuhr",
                asr: "Asr",
                maghrib: "Maghrib",
                isha: "Isha"
            ),
            isDefault: true
        ),
        
        // French
        AppLanguage(
            id: "fr",
            code: "fr",
            name: "French",
            nativeName: "Français",
            direction: .leftToRight,
            region: .europe,
            prayerNames: PrayerNames(
                fajr: "Fajr",
                dhuhr: "Dhuhr",
                asr: "Asr",
                maghrib: "Maghrib",
                isha: "Isha"
            )
        ),
        
        // Arabic (Standard)
        AppLanguage(
            id: "ar",
            code: "ar",
            name: "Arabic",
            nativeName: "العربية",
            direction: .rightToLeft,
            region: .middleEast,
            calendarType: .hijri,
            numberFormat: .arabic,
            dateFormat: .islamic,
            prayerNames: PrayerNames(
                fajr: "الفجر",
                dhuhr: "الظهر",
                asr: "العصر",
                maghrib: "المغرب",
                isha: "العشاء"
            )
        ),
        
        // Arabic (Lebanese)
        AppLanguage(
            id: "ar-lb",
            code: "ar-LB",
            name: "Arabic (Lebanese)",
            nativeName: "العربية (لبنانية)",
            direction: .rightToLeft,
            region: .middleEast,
            dialect: "Lebanese",
            calendarType: .hijri,
            numberFormat: .arabic,
            dateFormat: .islamic,
            prayerNames: PrayerNames(
                fajr: "الفجر",
                dhuhr: "الظهر",
                asr: "العصر",
                maghrib: "المغرب",
                isha: "العشاء"
            )
        ),
        
        // Arabic (Egyptian)
        AppLanguage(
            id: "ar-eg",
            code: "ar-EG",
            name: "Arabic (Egyptian)",
            nativeName: "العربية (مصرية)",
            direction: .rightToLeft,
            region: .northAfrica,
            dialect: "Egyptian",
            calendarType: .hijri,
            numberFormat: .arabic,
            dateFormat: .islamic,
            prayerNames: PrayerNames(
                fajr: "الفجر",
                dhuhr: "الظهر",
                asr: "العصر",
                maghrib: "المغرب",
                isha: "العشاء"
            )
        ),
        
        // Arabic (Gulf)
        AppLanguage(
            id: "ar-gulf",
            code: "ar-AE",
            name: "Arabic (Gulf)",
            nativeName: "العربية (خليجية)",
            direction: .rightToLeft,
            region: .middleEast,
            dialect: "Gulf",
            calendarType: .hijri,
            numberFormat: .arabic,
            dateFormat: .islamic,
            prayerNames: PrayerNames(
                fajr: "الفجر",
                dhuhr: "الظهر",
                asr: "العصر",
                maghrib: "المغرب",
                isha: "العشاء"
            )
        ),
        
        // Arabic (Maghrebi)
        AppLanguage(
            id: "ar-ma",
            code: "ar-MA",
            name: "Arabic (Maghrebi)",
            nativeName: "العربية (مغربية)",
            direction: .rightToLeft,
            region: .northAfrica,
            dialect: "Maghrebi",
            calendarType: .hijri,
            numberFormat: .arabic,
            dateFormat: .islamic,
            prayerNames: PrayerNames(
                fajr: "الفجر",
                dhuhr: "الظهر",
                asr: "العصر",
                maghrib: "المغرب",
                isha: "العشاء"
            )
        ),
        
        // Urdu
        AppLanguage(
            id: "ur",
            code: "ur",
            name: "Urdu",
            nativeName: "اردو",
            direction: .rightToLeft,
            region: .southAsia,
            calendarType: .hijri,
            numberFormat: .urdu,
            dateFormat: .islamic,
            prayerNames: PrayerNames(
                fajr: "فجر",
                dhuhr: "ظہر",
                asr: "عصر",
                maghrib: "مغرب",
                isha: "عشاء"
            )
        ),
        
        // Turkish
        AppLanguage(
            id: "tr",
            code: "tr",
            name: "Turkish",
            nativeName: "Türkçe",
            direction: .leftToRight,
            region: .middleEast,
            calendarType: .turkish,
            prayerNames: PrayerNames(
                fajr: "İmsak",
                dhuhr: "Öğle",
                asr: "İkindi",
                maghrib: "Akşam",
                isha: "Yatsı"
            )
        ),
        
        // Persian (Farsi)
        AppLanguage(
            id: "fa",
            code: "fa",
            name: "Persian",
            nativeName: "فارسی",
            direction: .rightToLeft,
            region: .centralAsia,
            calendarType: .persian,
            numberFormat: .persian,
            dateFormat: .persian,
            prayerNames: PrayerNames(
                fajr: "فجر",
                dhuhr: "ظهر",
                asr: "عصر",
                maghrib: "مغرب",
                isha: "عشاء"
            )
        ),
        
        // Indonesian
        AppLanguage(
            id: "id",
            code: "id",
            name: "Indonesian",
            nativeName: "Bahasa Indonesia",
            direction: .leftToRight,
            region: .southeastAsia,
            prayerNames: PrayerNames(
                fajr: "Subuh",
                dhuhr: "Dzuhur",
                asr: "Ashar",
                maghrib: "Maghrib",
                isha: "Isya"
            )
        ),
        
        // Malay
        AppLanguage(
            id: "ms",
            code: "ms",
            name: "Malay",
            nativeName: "Bahasa Melayu",
            direction: .leftToRight,
            region: .southeastAsia,
            prayerNames: PrayerNames(
                fajr: "Subuh",
                dhuhr: "Zohor",
                asr: "Asar",
                maghrib: "Maghrib",
                isha: "Isyak"
            )
        ),
        
        // Bengali
        AppLanguage(
            id: "bn",
            code: "bn",
            name: "Bengali",
            nativeName: "বাংলা",
            direction: .leftToRight,
            region: .southAsia,
            numberFormat: .western,
            prayerNames: PrayerNames(
                fajr: "ফজর",
                dhuhr: "জোহর",
                asr: "আসর",
                maghrib: "মাগরিব",
                isha: "এশা"
            )
        ),
        
        // Swahili
        AppLanguage(
            id: "sw",
            code: "sw",
            name: "Swahili",
            nativeName: "Kiswahili",
            direction: .leftToRight,
            region: .subSaharanAfrica,
            prayerNames: PrayerNames(
                fajr: "Alfajiri",
                dhuhr: "Adhuhuri",
                asr: "Alasiri",
                maghrib: "Magharibi",
                isha: "Isha"
            )
        ),
        
        // Hausa
        AppLanguage(
            id: "ha",
            code: "ha",
            name: "Hausa",
            nativeName: "Hausa",
            direction: .leftToRight,
            region: .subSaharanAfrica,
            prayerNames: PrayerNames(
                fajr: "Alfajiri",
                dhuhr: "Lahadi",
                asr: "Alasiri",
                maghrib: "Magaribi",
                isha: "Isha"
            )
        ),
        
        // Russian (for Central Asian Muslims)
        AppLanguage(
            id: "ru",
            code: "ru",
            name: "Russian",
            nativeName: "Русский",
            direction: .leftToRight,
            region: .centralAsia,
            prayerNames: PrayerNames(
                fajr: "Фаджр",
                dhuhr: "Зухр",
                asr: "Аср",
                maghrib: "Магриб",
                isha: "Иша"
            )
        )
    ]
    
    /// Get language by ID
    static func getLanguage(by id: String) -> AppLanguage? {
        return supportedLanguages.first { $0.id == id }
    }
    
    /// Get language by code
    static func getLanguage(byCode code: String) -> AppLanguage? {
        return supportedLanguages.first { $0.code == code }
    }
    
    /// Get default language
    static var defaultLanguage: AppLanguage {
        return supportedLanguages.first { $0.isDefault } ?? supportedLanguages.first!
    }
    
    /// Get system preferred language
    static var systemPreferredLanguage: AppLanguage {
        let preferredLanguages = Locale.preferredLanguages
        
        for preferredLang in preferredLanguages {
            let langCode = String(preferredLang.prefix(2))
            
            // Try exact match first
            if let language = supportedLanguages.first(where: { $0.code == preferredLang }) {
                return language
            }
            
            // Try language code match
            if let language = supportedLanguages.first(where: { $0.code.hasPrefix(langCode) }) {
                return language
            }
        }
        
        return defaultLanguage
    }
    
    /// Get languages by region
    static func getLanguages(for region: LanguageRegion) -> [AppLanguage] {
        return supportedLanguages.filter { $0.region == region }
    }
    
    /// Get RTL languages
    static var rtlLanguages: [AppLanguage] {
        return supportedLanguages.filter { $0.isRTL }
    }
    
    /// Get LTR languages
    static var ltrLanguages: [AppLanguage] {
        return supportedLanguages.filter { !$0.isRTL }
    }
}

// MARK: - String Extensions for Numerals

extension String {
    func applyArabicNumerals() -> String {
        let arabicNumerals = ["٠", "١", "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩"]
        var result = self
        
        for (index, numeral) in arabicNumerals.enumerated() {
            result = result.replacingOccurrences(of: "\(index)", with: numeral)
        }
        
        return result
    }
    
    func applyPersianNumerals() -> String {
        let persianNumerals = ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
        var result = self
        
        for (index, numeral) in persianNumerals.enumerated() {
            result = result.replacingOccurrences(of: "\(index)", with: numeral)
        }
        
        return result
    }
    
    func applyUrduNumerals() -> String {
        let urduNumerals = ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
        var result = self
        
        for (index, numeral) in urduNumerals.enumerated() {
            result = result.replacingOccurrences(of: "\(index)", with: numeral)
        }
        
        return result
    }
}

// MARK: - Localization Keys

/// Common localization keys used throughout the app
public enum LocalizationKey: String, CaseIterable {
    // Prayer names
    case prayerFajr = "prayer.fajr"
    case prayerDhuhr = "prayer.dhuhr"
    case prayerAsr = "prayer.asr"
    case prayerMaghrib = "prayer.maghrib"
    case prayerIsha = "prayer.isha"
    
    // Navigation
    case navPrayerTimes = "nav.prayer_times"
    case navGuides = "nav.guides"
    case navKnowledge = "nav.knowledge"
    case navJournal = "nav.journal"
    case navQibla = "nav.qibla"
    case navSettings = "nav.settings"
    
    // Common actions
    case actionSave = "action.save"
    case actionCancel = "action.cancel"
    case actionEdit = "action.edit"
    case actionDelete = "action.delete"
    case actionShare = "action.share"
    case actionClose = "action.close"
    case actionDone = "action.done"
    case actionRetry = "action.retry"
    case actionSearch = "action.search"
    
    // Time-related
    case timeMinutes = "time.minutes"
    case timeHours = "time.hours"
    case timeDays = "time.days"
    case timeWeeks = "time.weeks"
    case timeMonths = "time.months"
    case timeYears = "time.years"
    
    // Prayer states
    case prayerStateCurrent = "prayer.state.current"
    case prayerStateUpcoming = "prayer.state.upcoming"
    case prayerStatePassed = "prayer.state.passed"
    case prayerStateOnTime = "prayer.state.on_time"
    case prayerStateLate = "prayer.state.late"
    
    // Error messages
    case errorGeneral = "error.general"
    case errorNetwork = "error.network"
    case errorLocation = "error.location"
    case errorPermission = "error.permission"
    
    // Success messages
    case successSaved = "success.saved"
    case successDeleted = "success.deleted"
    case successUpdated = "success.updated"
    
    // Madhab names
    case madhabShafi = "madhab.shafi"
    case madhabHanafi = "madhab.hanafi"
    case madhabMaliki = "madhab.maliki"
    case madhabHanbali = "madhab.hanbali"
    case madhabJafari = "madhab.jafari"
    
    // Settings
    case settingsLanguage = "settings.language"
    case settingsTheme = "settings.theme"
    case settingsNotifications = "settings.notifications"
    case settingsLocation = "settings.location"
    case settingsAbout = "settings.about"
    
    // Qibla
    case qiblaDirection = "qibla.direction"
    case qiblaDistance = "qibla.distance"
    case qiblaAccuracy = "qibla.accuracy"
    case qiblaCalibrate = "qibla.calibrate"
    
    // Journal
    case journalEntry = "journal.entry"
    case journalMood = "journal.mood"
    case journalNotes = "journal.notes"
    case journalStreak = "journal.streak"
    case journalStats = "journal.stats"
    
    // Knowledge
    case knowledgeSearch = "knowledge.search"
    case knowledgeQuran = "knowledge.quran"
    case knowledgeHadith = "knowledge.hadith"
    case knowledgeAI = "knowledge.ai"
    
    public var key: String {
        return self.rawValue
    }
}