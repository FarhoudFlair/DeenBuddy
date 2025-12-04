import Foundation
import Combine
import CoreLocation

/// A dummy implementation of PrayerTimeServiceProtocol for testing and preview purposes
@MainActor
public class DummyPrayerTimeService: PrayerTimeServiceProtocol {
    public var todaysPrayerTimes: [PrayerTime] = []
    
    public var todaysPrayerTimesPublisher: AnyPublisher<[PrayerTime], Never> {
        Just(todaysPrayerTimes).eraseToAnyPublisher()
    }
    public var nextPrayer: PrayerTime? = nil
    public var timeUntilNextPrayer: TimeInterval? = nil
    public var calculationMethod: CalculationMethod = .muslimWorldLeague
    public var madhab: Madhab = .shafi
    public var isLoading: Bool = false
    public var error: Error? = nil
    
    public init() {}
    
    public func calculatePrayerTimes(for location: CLLocation, date: Date) async throws -> [PrayerTime] {
        throw NSError(domain: "DummyPrayerTimeService", code: -1, userInfo: nil)
    }
    
    public func refreshPrayerTimes() async {}
    public func refreshTodaysPrayerTimes() async {}
    
    public func getPrayerTimes(from startDate: Date, to endDate: Date) async throws -> [Date: [PrayerTime]] {
        throw NSError(domain: "DummyPrayerTimeService", code: -1, userInfo: nil)
    }

    public func getTomorrowPrayerTimes(for location: CLLocation) async throws -> [PrayerTime] {
        throw NSError(domain: "DummyPrayerTimeService", code: -1, userInfo: nil)
    }

    public func getFuturePrayerTimes(for date: Date, location: CLLocation?) async throws -> FuturePrayerTimeResult {
        throw NSError(domain: "DummyPrayerTimeService", code: -1, userInfo: nil)
    }

    public func getFuturePrayerTimes(from startDate: Date, to endDate: Date, location: CLLocation?) async throws -> [FuturePrayerTimeResult] {
        throw NSError(domain: "DummyPrayerTimeService", code: -1, userInfo: nil)
    }

    public func validateLookaheadDate(_ date: Date) throws -> DisclaimerLevel {
        throw NSError(domain: "DummyPrayerTimeService", code: -1, userInfo: nil)
    }

    public func isHighLatitudeLocation(_ location: CLLocation) -> Bool {
        false
    }

    public func getCurrentLocation() async throws -> CLLocation {
        throw NSError(domain: "DummyPrayerTimeService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Dummy service cannot provide location"])
    }
    
    public func triggerDynamicIslandForNextPrayer() async {
        // Dummy implementation - no-op
    }
}
