import Foundation

// MARK: - Prayer Time Models

public enum PrayerTimeType: String, CaseIterable, Codable {
    case fajr = "Fajr"
    case dhuhr = "Dhuhr"
    case asr = "Asr"
    case maghrib = "Maghrib"
    case isha = "Isha"

    public var displayName: String {
        return rawValue
    }

    public var notificationTitle: String {
        return "\(displayName) Prayer Time"
    }
}

public struct PrayerTimes: Codable, Equatable {
    public let date: Date
    public let fajr: Date
    public let dhuhr: Date
    public let asr: Date
    public let maghrib: Date
    public let isha: Date
    public let calculationMethod: String
    public let location: LocationCoordinate
    
    public init(
        date: Date,
        fajr: Date,
        dhuhr: Date,
        asr: Date,
        maghrib: Date,
        isha: Date,
        calculationMethod: String,
        location: LocationCoordinate
    ) {
        self.date = date
        self.fajr = fajr
        self.dhuhr = dhuhr
        self.asr = asr
        self.maghrib = maghrib
        self.isha = isha
        self.calculationMethod = calculationMethod
        self.location = location
    }
    
    public func time(for prayer: PrayerTimeType) -> Date {
        switch prayer {
        case .fajr: return fajr
        case .dhuhr: return dhuhr
        case .asr: return asr
        case .maghrib: return maghrib
        case .isha: return isha
        }
    }

    public var allPrayers: [(PrayerTimeType, Date)] {
        return [
            (.fajr, fajr),
            (.dhuhr, dhuhr),
            (.asr, asr),
            (.maghrib, maghrib),
            (.isha, isha)
        ]
    }

    public func nextPrayer(from currentTime: Date = Date()) -> (PrayerTimeType, Date)? {
        let upcomingPrayers = allPrayers.filter { $0.1 > currentTime }
        return upcomingPrayers.first
    }

    public func currentPrayer(at currentTime: Date = Date()) -> PrayerTimeType? {
        let sortedPrayers = allPrayers.sorted { $0.1 < $1.1 }
        
        for i in 0..<sortedPrayers.count {
            let currentPrayerTime = sortedPrayers[i].1
            let nextPrayerTime = i < sortedPrayers.count - 1 ? sortedPrayers[i + 1].1 : nil
            
            if currentTime >= currentPrayerTime {
                if let nextTime = nextPrayerTime, currentTime < nextTime {
                    return sortedPrayers[i].0
                } else if nextPrayerTime == nil {
                    return sortedPrayers[i].0
                }
            }
        }
        
        return nil
    }
}

public enum CalculationMethod: String, CaseIterable, Codable, Identifiable, Sendable {
    public var id: String { rawValue }
    case muslimWorldLeague = "MuslimWorldLeague"
    case egyptian = "Egyptian"
    case karachi = "Karachi"
    case ummAlQura = "UmmAlQura"
    case dubai = "Dubai"
    case moonsightingCommittee = "MoonsightingCommittee"
    case northAmerica = "NorthAmerica"
    case kuwait = "Kuwait"
    case qatar = "Qatar"
    case singapore = "Singapore"
    case jafariLeva = "JafariLeva"
    case jafariTehran = "JafariTehran"
    case fcnaCanada = "FCNACanada"
    
    public var displayName: String {
        switch self {
        case .muslimWorldLeague: return "Muslim World League"
        case .egyptian: return "Egyptian General Authority"
        case .karachi: return "University of Islamic Sciences, Karachi"
        case .ummAlQura: return "Umm Al-Qura University, Makkah"
        case .dubai: return "Dubai"
        case .moonsightingCommittee: return "Moonsighting Committee Worldwide"
        case .northAmerica: return "Islamic Society of North America"
        case .kuwait: return "Kuwait"
        case .qatar: return "Qatar"
        case .singapore: return "Singapore"
        case .jafariLeva: return "Ja'fari (Leva Institute, Qum)"
        case .jafariTehran: return "Ja'fari (Tehran IOG)"
        case .fcnaCanada: return "FCNA (Canada)"
        }
    }
    
    public var description: String {
        switch self {
        case .muslimWorldLeague:
            return "Standard method used by most Islamic organizations worldwide"
        case .egyptian:
            return "Used in Egypt, Syria, Iraq, Lebanon, Malaysia, and parts of the USA"
        case .karachi:
            return "Used in Pakistan, Bangladesh, India, Afghanistan, and parts of Europe"
        case .ummAlQura:
            return "Used in Saudi Arabia"
        case .dubai:
            return "Used in UAE"
        case .moonsightingCommittee:
            return "Used by communities that follow moon sighting"
        case .northAmerica:
            return "Used in North America"
        case .kuwait:
            return "Used in Kuwait"
        case .qatar:
            return "Used in Qatar"
        case .singapore:
            return "Used in Singapore"
        case .jafariLeva:
            return "Ja'fari method with 16°/14° angles (Leva Institute, Qum)"
        case .jafariTehran:
            return "Ja'fari method with 17.7°/14° angles (Tehran Institute of Geophysics)"
        case .fcnaCanada:
            return "Fiqh Council of North America method for Canada (13°/13°)"
        }
    }
}

