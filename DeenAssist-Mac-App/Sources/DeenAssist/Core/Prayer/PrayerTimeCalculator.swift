import Foundation
import CoreLocation
import Adhan

/// Concrete implementation of PrayerCalculatorProtocol using AdhanSwift library
public final class PrayerTimeCalculator: PrayerCalculatorProtocol {
    
    // MARK: - Properties
    
    private let dataManager: DataManagerProtocol
    private let calendar = Calendar.current
    
    // MARK: - Initialization
    
    public init(dataManager: DataManagerProtocol = CoreDataManager.shared) {
        self.dataManager = dataManager
    }
    
    // MARK: - PrayerCalculatorProtocol Implementation
    
    public func calculatePrayerTimes(for date: Date, config: PrayerCalculationConfig) throws -> PrayerTimes {
        // Validate inputs
        guard CLLocationCoordinate2DIsValid(config.location) else {
            throw PrayerCalculationError.invalidLocation
        }
        
        // Create Adhan coordinates
        let coordinates = Coordinates(latitude: config.location.latitude, longitude: config.location.longitude)
        
        // Convert our calculation method to Adhan's calculation method
        let adhanMethod = try convertToAdhanCalculationMethod(config.calculationMethod)
        
        // Create calculation parameters
        var calculationParameters = adhanMethod.params
        calculationParameters.madhab = convertToAdhanMadhab(config.madhab)
        
        // Calculate prayer times using Adhan
        guard let adhanPrayerTimes = Adhan.PrayerTimes(coordinates: coordinates, date: date, calculationParameters: calculationParameters) else {
            throw PrayerCalculationError.calculationFailed("AdhanSwift failed to calculate prayer times")
        }
        
        // Convert to our PrayerTimes model
        let prayerTimes = PrayerTimes(
            date: date,
            fajr: adhanPrayerTimes.fajr,
            dhuhr: adhanPrayerTimes.dhuhr,
            asr: adhanPrayerTimes.asr,
            maghrib: adhanPrayerTimes.maghrib,
            isha: adhanPrayerTimes.isha,
            calculationMethod: config.calculationMethod.rawValue
        )
        
        // Cache the calculated prayer times
        cachePrayerTimes(prayerTimes)
        
        return prayerTimes
    }
    
    public func getCachedPrayerTimes(for date: Date) -> PrayerTimes? {
        guard let cacheEntry = dataManager.getPrayerCache(for: date) else {
            return nil
        }
        
        return PrayerTimes(
            date: cacheEntry.date,
            fajr: cacheEntry.fajr,
            dhuhr: cacheEntry.dhuhr,
            asr: cacheEntry.asr,
            maghrib: cacheEntry.maghrib,
            isha: cacheEntry.isha,
            calculationMethod: cacheEntry.sourceMethod
        )
    }
    
    public func cachePrayerTimes(_ prayerTimes: PrayerTimes) {
        let cacheEntry = PrayerCacheEntry(
            date: prayerTimes.date,
            fajr: prayerTimes.fajr,
            dhuhr: prayerTimes.dhuhr,
            asr: prayerTimes.asr,
            maghrib: prayerTimes.maghrib,
            isha: prayerTimes.isha,
            sourceMethod: prayerTimes.calculationMethod
        )
        
        do {
            try dataManager.savePrayerCache(cacheEntry)
        } catch {
            print("Failed to cache prayer times: \(error)")
        }
    }
    
    public func getNextPrayer(config: PrayerCalculationConfig) throws -> (name: String, time: Date) {
        let now = Date()
        let today = calendar.startOfDay(for: now)
        
        // Try to get cached prayer times for today first
        var todayPrayerTimes = getCachedPrayerTimes(for: today)
        
        // If not cached, calculate them
        if todayPrayerTimes == nil {
            todayPrayerTimes = try calculatePrayerTimes(for: today, config: config)
        }
        
        guard let prayerTimes = todayPrayerTimes else {
            throw PrayerCalculationError.calculationFailed("Could not get prayer times for today")
        }
        
        // Check each prayer time to find the next one
        let prayers = [
            ("Fajr", prayerTimes.fajr),
            ("Dhuhr", prayerTimes.dhuhr),
            ("Asr", prayerTimes.asr),
            ("Maghrib", prayerTimes.maghrib),
            ("Isha", prayerTimes.isha)
        ]
        
        // Find the next prayer today
        for (name, time) in prayers {
            if time > now {
                return (name, time)
            }
        }
        
        // If no prayer left today, get tomorrow's Fajr
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let tomorrowPrayerTimes = try calculatePrayerTimes(for: tomorrow, config: config)
        
        return ("Fajr", tomorrowPrayerTimes.fajr)
    }
    
    public func getCurrentPrayer(config: PrayerCalculationConfig, tolerance: TimeInterval = 300) -> String? {
        let now = Date()
        let today = calendar.startOfDay(for: now)
        
        // Try to get cached prayer times for today first
        var todayPrayerTimes = getCachedPrayerTimes(for: today)
        
        // If not cached, calculate them
        if todayPrayerTimes == nil {
            do {
                todayPrayerTimes = try calculatePrayerTimes(for: today, config: config)
            } catch {
                print("Failed to calculate prayer times for current prayer check: \(error)")
                return nil
            }
        }
        
        guard let prayerTimes = todayPrayerTimes else {
            return nil
        }
        
        // Check each prayer time to see if we're within tolerance
        let prayers = [
            ("Fajr", prayerTimes.fajr),
            ("Dhuhr", prayerTimes.dhuhr),
            ("Asr", prayerTimes.asr),
            ("Maghrib", prayerTimes.maghrib),
            ("Isha", prayerTimes.isha)
        ]
        
        for (name, time) in prayers {
            let timeDifference = abs(now.timeIntervalSince(time))
            if timeDifference <= tolerance {
                return name
            }
        }
        
        return nil
    }

    // MARK: - Private Helper Methods

    private func convertToAdhanCalculationMethod(_ method: CalculationMethod) throws -> Adhan.CalculationMethod {
        switch method {
        case .muslimWorldLeague:
            return Adhan.CalculationMethod.muslimWorldLeague
        case .egyptian:
            return Adhan.CalculationMethod.egyptian
        case .karachi:
            return Adhan.CalculationMethod.karachi
        case .ummAlQura:
            return Adhan.CalculationMethod.ummAlQura
        case .dubai:
            return Adhan.CalculationMethod.dubai
        case .moonsightingCommittee:
            return Adhan.CalculationMethod.moonsightingCommittee
        case .northAmerica:
            return Adhan.CalculationMethod.northAmerica
        case .kuwait:
            return Adhan.CalculationMethod.kuwait
        case .qatar:
            return Adhan.CalculationMethod.qatar
        case .singapore:
            return Adhan.CalculationMethod.singapore
        case .tehran:
            return Adhan.CalculationMethod.tehran
        }
    }

    private func convertToAdhanMadhab(_ madhab: Madhab) -> Adhan.Madhab {
        switch madhab {
        case .shafi:
            return .shafi
        case .hanafi:
            return .hanafi
        }
    }

    /// Clean up old cached prayer times (older than 30 days)
    public func cleanupOldCache() {
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()

        do {
            try dataManager.deleteOldPrayerCache(before: thirtyDaysAgo)
        } catch {
            print("Failed to cleanup old prayer cache: \(error)")
        }
    }

    /// Get prayer times for a date range (useful for weekly/monthly views)
    public func getPrayerTimesRange(from startDate: Date, to endDate: Date, config: PrayerCalculationConfig) throws -> [PrayerTimes] {
        var prayerTimesArray: [PrayerTimes] = []
        var currentDate = startDate

        while currentDate <= endDate {
            // Try to get cached prayer times first
            var prayerTimes = getCachedPrayerTimes(for: currentDate)

            // If not cached, calculate them
            if prayerTimes == nil {
                prayerTimes = try calculatePrayerTimes(for: currentDate, config: config)
            }

            if let prayerTimes = prayerTimes {
                prayerTimesArray.append(prayerTimes)
            }

            // Move to next day
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }

        return prayerTimesArray
    }
}
