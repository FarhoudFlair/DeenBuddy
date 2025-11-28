import Foundation
import Combine
import CoreLocation

/// Mock implementation of PrayerTimeServiceProtocol for UI development
@MainActor
public class MockPrayerTimeService: PrayerTimeServiceProtocol {
    @Published public var todaysPrayerTimes: [PrayerTime] = []
    @Published public var nextPrayer: PrayerTime? = nil
    @Published public var timeUntilNextPrayer: TimeInterval? = nil
    @Published public var calculationMethod: CalculationMethod = .muslimWorldLeague
    @Published public var madhab: Madhab = .shafi
    @Published public var isLoading: Bool = false
    @Published public var error: Error? = nil

    private var timer: Timer?

    // Mock location for testing (Mecca coordinates)
    private let mockLocation = CLLocation(latitude: 21.4225, longitude: 39.8262)
    
    public init() {
        generateMockPrayerTimes()
        startTimer()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    public func calculatePrayerTimes(for location: CLLocation, date: Date) async throws -> [PrayerTime] {
        isLoading = true
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        let prayerTimes = generateMockPrayerTimes(for: date)
        
        isLoading = false
        return prayerTimes
    }
    
    public func refreshPrayerTimes() async {
        isLoading = true
        
        // Simulate refresh delay
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        generateMockPrayerTimes()
        isLoading = false
    }
    
    public func refreshTodaysPrayerTimes() async {
        await refreshPrayerTimes()
    }
    
    public func getPrayerTimes(from startDate: Date, to endDate: Date) async throws -> [Date: [PrayerTime]] {
        var result: [Date: [PrayerTime]] = [:]

        let calendar = Calendar.current
        var currentDate = startDate

        while currentDate <= endDate {
            result[currentDate] = generateMockPrayerTimes(for: currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }

        return result
    }

    public func getTomorrowPrayerTimes(for location: CLLocation) async throws -> [PrayerTime] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000)
        
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return generateMockPrayerTimes(for: tomorrow)
    }
    
    public func getCurrentLocation() async throws -> CLLocation {
        return mockLocation
    }
    
    public func getFuturePrayerTimes(for date: Date, location: CLLocation?) async throws -> FuturePrayerTimeResult {
        let targetLocation = location ?? mockLocation
        let disclaimer = try validateLookaheadDate(date)
        let hijriDate = HijriDate(from: date)
        let isHighLat = isHighLatitudeLocation(targetLocation)

        return FuturePrayerTimeResult(
            date: date,
            prayerTimes: generateMockPrayerTimes(for: date),
            hijriDate: hijriDate,
            isRamadan: false,
            disclaimerLevel: disclaimer,
            calculationTimezone: TimeZone.current,
            isHighLatitude: isHighLat,
            precision: disclaimer == .today || disclaimer == .shortTerm ? .exact : .window(minutes: 30)
        )
    }

    public func getFuturePrayerTimes(from startDate: Date, to endDate: Date, location: CLLocation?) async throws -> [FuturePrayerTimeResult] {
        var results: [FuturePrayerTimeResult] = []
        var current = startDate
        let calendar = Calendar.current
        while current <= endDate {
            results.append(try await getFuturePrayerTimes(for: current, location: location))
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return results
    }

    public func validateLookaheadDate(_ date: Date) throws -> DisclaimerLevel {
        let calendar = Calendar.current
        let today = Date()

        if calendar.isDate(date, inSameDayAs: today) {
            return .today
        }

        guard let months = calendar.dateComponents([.month], from: today, to: date).month else {
            throw PrayerTimeError.invalidDate
        }

        if months < 0 {
            throw PrayerTimeError.invalidDate
        }

        switch months {
        case 0...12: return .shortTerm
        case 13...60: return .mediumTerm
        default: return .longTerm
        }
    }

    public func isHighLatitudeLocation(_ location: CLLocation) -> Bool {
        abs(location.coordinate.latitude) > 55.0
    }
    
    public func triggerDynamicIslandForNextPrayer() async {
        // Mock implementation - just print for debugging
        print("Mock: triggerDynamicIslandForNextPrayer called")
        if let next = nextPrayer {
            print("Mock: Would trigger Dynamic Island for \(next.prayer.displayName) at \(next.time)")
        } else {
            print("Mock: No next prayer available")
        }
    }
    
    private func generateMockPrayerTimes(for date: Date = Date()) -> [PrayerTime] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        
        // Generate realistic prayer times for today
        let prayerTimes = [
            PrayerTime(prayer: .fajr, time: calendar.date(byAdding: .hour, value: 5, to: today)!.addingTimeInterval(25 * 60)),
            PrayerTime(prayer: .dhuhr, time: calendar.date(byAdding: .hour, value: 12, to: today)!.addingTimeInterval(30 * 60)),
            PrayerTime(prayer: .asr, time: calendar.date(byAdding: .hour, value: 15, to: today)!.addingTimeInterval(45 * 60)),
            PrayerTime(prayer: .maghrib, time: calendar.date(byAdding: .hour, value: 18, to: today)!.addingTimeInterval(15 * 60)),
            PrayerTime(prayer: .isha, time: calendar.date(byAdding: .hour, value: 19, to: today)!.addingTimeInterval(45 * 60))
        ]
        
        if calendar.isDate(date, inSameDayAs: Date()) {
            todaysPrayerTimes = prayerTimes
            updateNextPrayer()
        }
        
        return prayerTimes
    }
    
    private func updateNextPrayer() {
        let now = Date()
        nextPrayer = todaysPrayerTimes.first { $0.time > now }
        
        if let next = nextPrayer {
            timeUntilNextPrayer = next.time.timeIntervalSince(now)
        } else {
            // If no more prayers today, next prayer is Fajr tomorrow
            let calendar = Calendar.current
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
            let tomorrowsPrayerTimes = generateMockPrayerTimes(for: tomorrow)
            nextPrayer = tomorrowsPrayerTimes.first
            
            if let next = nextPrayer {
                timeUntilNextPrayer = next.time.timeIntervalSince(now)
            }
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                self.updateNextPrayer()
            }
        }
    }
}
