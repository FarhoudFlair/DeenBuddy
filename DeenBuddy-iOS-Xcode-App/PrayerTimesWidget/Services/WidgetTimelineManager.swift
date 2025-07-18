import Foundation
import WidgetKit

/// Manager for widget timeline generation and refresh strategies
class WidgetTimelineManager {
    
    // MARK: - Singleton
    
    static let shared = WidgetTimelineManager()
    
    private init() {}
    
    // MARK: - Timeline Generation
    
    /// Generate timeline entries for prayer widgets with strategic refresh times
    func generateTimeline(from currentEntry: PrayerWidgetEntry, maxEntries: Int = 20) -> [PrayerWidgetEntry] {
        var entries: [PrayerWidgetEntry] = []
        let now = Date()
        let calendar = Calendar.current
        
        // Add current entry
        entries.append(currentEntry)
        
        // Generate entries for countdown updates (every 5 minutes for next hour)
        for minuteOffset in stride(from: 5, through: 60, by: 5) {
            let entryDate = calendar.date(byAdding: .minute, value: minuteOffset, to: now) ?? now
            let updatedEntry = createUpdatedEntry(from: currentEntry, at: entryDate)
            entries.append(updatedEntry)
        }
        
        // Generate entries for prayer time transitions
        let prayerTransitionEntries = generatePrayerTransitionEntries(from: currentEntry, startingFrom: now)
        entries.append(contentsOf: prayerTransitionEntries)
        
        // Generate entries for daily transitions (midnight)
        let dailyTransitionEntries = generateDailyTransitionEntries(from: currentEntry, startingFrom: now)
        entries.append(contentsOf: dailyTransitionEntries)
        
        // Sort by date and limit to maxEntries
        entries.sort { $0.date < $1.date }
        return Array(entries.prefix(maxEntries))
    }
    
    /// Determine the next strategic refresh time
    func getNextRefreshDate(from entry: PrayerWidgetEntry) -> Date {
        let now = Date()
        let calendar = Calendar.current
        
        // Priority 1: Next prayer time (most important)
        if let nextPrayerTime = entry.widgetData.nextPrayer?.time,
           nextPrayerTime > now {
            return nextPrayerTime
        }
        
        // Priority 2: 5 minutes before next prayer (for advance notification)
        if let nextPrayerTime = entry.widgetData.nextPrayer?.time {
            let fiveMinutesBefore = calendar.date(byAdding: .minute, value: -5, to: nextPrayerTime) ?? nextPrayerTime
            if fiveMinutesBefore > now {
                return fiveMinutesBefore
            }
        }
        
        // Priority 3: Midnight for new day
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        let midnight = calendar.startOfDay(for: tomorrow)
        
        // Priority 4: Every 15 minutes during active hours (5 AM - 11 PM)
        let currentHour = calendar.component(.hour, from: now)
        if currentHour >= 5 && currentHour <= 23 {
            let next15Minutes = calendar.date(byAdding: .minute, value: 15, to: now) ?? now
            return min(midnight, next15Minutes)
        }
        
        // Priority 5: Default to midnight
        return midnight
    }
    
    /// Check if widget data needs refresh based on staleness
    func shouldRefreshData(for entry: PrayerWidgetEntry) -> Bool {
        let now = Date()
        let dataAge = now.timeIntervalSince(entry.widgetData.lastUpdated)
        
        // Refresh if data is older than 5 minutes
        if dataAge > 300 {
            return true
        }
        
        // Refresh if next prayer time has passed
        if let nextPrayerTime = entry.widgetData.nextPrayer?.time,
           nextPrayerTime <= now {
            return true
        }
        
        // Refresh if it's a new day
        let calendar = Calendar.current
        if !calendar.isDate(entry.widgetData.lastUpdated, inSameDayAs: now) {
            return true
        }
        
        return false
    }
    
    // MARK: - Private Helper Methods
    
    private func createUpdatedEntry(from baseEntry: PrayerWidgetEntry, at date: Date) -> PrayerWidgetEntry {
        var updatedWidgetData = baseEntry.widgetData

        // Update time until next prayer
        if let nextPrayerTime = updatedWidgetData.nextPrayer?.time {
            let timeUntilNext = nextPrayerTime.timeIntervalSince(date)
            if timeUntilNext > 0 {
                updatedWidgetData = WidgetData(
                    nextPrayer: updatedWidgetData.nextPrayer,
                    timeUntilNextPrayer: timeUntilNext,
                    todaysPrayerTimes: updatedWidgetData.todaysPrayerTimes,
                    hijriDate: updatedWidgetData.hijriDate,
                    location: updatedWidgetData.location,
                    calculationMethod: updatedWidgetData.calculationMethod,
                    lastUpdated: updatedWidgetData.lastUpdated
                )
            }
        }

        return PrayerWidgetEntry(
            date: date,
            widgetData: updatedWidgetData,
            configuration: baseEntry.configuration
        )
    }
    
    private func generatePrayerTransitionEntries(from baseEntry: PrayerWidgetEntry, startingFrom: Date) -> [PrayerWidgetEntry] {
        var entries: [PrayerWidgetEntry] = []
        let calendar = Calendar.current
        
        // Create entries for each upcoming prayer time
        for prayerTime in baseEntry.widgetData.todaysPrayerTimes {
            if prayerTime.time > startingFrom {
                // Entry at prayer time
                let prayerEntry = createUpdatedEntry(from: baseEntry, at: prayerTime.time)
                entries.append(prayerEntry)
                
                // Entry 5 minutes before prayer time
                if let fiveMinutesBefore = calendar.date(byAdding: .minute, value: -5, to: prayerTime.time),
                   fiveMinutesBefore > startingFrom {
                    let beforeEntry = createUpdatedEntry(from: baseEntry, at: fiveMinutesBefore)
                    entries.append(beforeEntry)
                }
            }
        }
        
        return entries
    }
    
    private func generateDailyTransitionEntries(from baseEntry: PrayerWidgetEntry, startingFrom: Date) -> [PrayerWidgetEntry] {
        var entries: [PrayerWidgetEntry] = []
        let calendar = Calendar.current
        
        // Generate entries for next few days at midnight
        for dayOffset in 1...3 {
            if let futureDate = calendar.date(byAdding: .day, value: dayOffset, to: startingFrom) {
                let midnight = calendar.startOfDay(for: futureDate)
                
                // Create entry with updated Hijri date for new day
                let updatedHijriDate = HijriDate(from: midnight)
                var updatedWidgetData = baseEntry.widgetData
                updatedWidgetData = WidgetData(
                    nextPrayer: updatedWidgetData.nextPrayer,
                    timeUntilNextPrayer: updatedWidgetData.timeUntilNextPrayer,
                    todaysPrayerTimes: updatedWidgetData.todaysPrayerTimes,
                    hijriDate: updatedHijriDate,
                    location: updatedWidgetData.location,
                    calculationMethod: updatedWidgetData.calculationMethod,
                    lastUpdated: updatedWidgetData.lastUpdated
                )
                
                let midnightEntry = PrayerWidgetEntry(
                    date: midnight,
                    widgetData: updatedWidgetData,
                    configuration: baseEntry.configuration
                )
                
                entries.append(midnightEntry)
            }
        }
        
        return entries
    }
    
    private func calculateRelevanceScore(for date: Date, widgetData: WidgetData) -> Float {
        let now = Date()
        
        // Higher relevance for times closer to prayer times
        if let nextPrayerTime = widgetData.nextPrayer?.time {
            let timeUntilPrayer = nextPrayerTime.timeIntervalSince(date)
            
            // Maximum relevance within 30 minutes of prayer
            if timeUntilPrayer <= 1800 && timeUntilPrayer > 0 {
                return 1.0
            }
            
            // High relevance within 1 hour of prayer
            if timeUntilPrayer <= 3600 && timeUntilPrayer > 0 {
                return 0.8
            }
            
            // Medium relevance within 3 hours of prayer
            if timeUntilPrayer <= 10800 && timeUntilPrayer > 0 {
                return 0.6
            }
        }
        
        // Lower relevance for other times
        return 0.3
    }
    
    // MARK: - Helper Methods
    

}

// MARK: - Widget Background Refresh Manager

/// Manager for coordinating background refresh of widget data
class WidgetBackgroundRefreshManager {
    
    // MARK: - Singleton
    
    static let shared = WidgetBackgroundRefreshManager()
    
    private init() {}
    
    // MARK: - Background Refresh
    
    /// Trigger background refresh of all prayer widgets
    func refreshAllWidgets() {
        guard #available(iOS 14.0, *) else { return }
        
        WidgetCenter.shared.reloadAllTimelines()
        print("🔄 Triggered background refresh for all prayer widgets")
    }
    
    /// Refresh specific widget kind
    func refreshWidget(kind: String) {
        guard #available(iOS 14.0, *) else { return }
        
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
        print("🔄 Triggered background refresh for widget kind: \(kind)")
    }
    
    /// Schedule background refresh at strategic times
    func scheduleStrategicRefresh(for widgetData: WidgetData) {
        let calendar = Calendar.current
        let now = Date()
        
        // Schedule refresh 5 minutes before next prayer
        if let nextPrayerTime = widgetData.nextPrayer?.time,
           let fiveMinutesBefore = calendar.date(byAdding: .minute, value: -5, to: nextPrayerTime),
           fiveMinutesBefore > now {
            
            scheduleBackgroundRefresh(at: fiveMinutesBefore, reason: "Pre-prayer refresh")
        }
        
        // Schedule refresh at next prayer time
        if let nextPrayerTime = widgetData.nextPrayer?.time,
           nextPrayerTime > now {
            
            scheduleBackgroundRefresh(at: nextPrayerTime, reason: "Prayer time transition")
        }
        
        // Schedule refresh at midnight for new day
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        let midnight = calendar.startOfDay(for: tomorrow)
        scheduleBackgroundRefresh(at: midnight, reason: "Daily refresh")
    }
    
    /// Get current widget relevance for iOS 17+ features
    @available(iOS 17.0, *)
    func getCurrentRelevance(for widgetData: WidgetData) -> TimelineEntryRelevance? {
        guard let nextPrayerTime = widgetData.nextPrayer?.time else { return nil }
        
        let now = Date()
        let timeUntilPrayer = nextPrayerTime.timeIntervalSince(now)
        
        // High relevance approaching prayer time
        if timeUntilPrayer <= 1800 && timeUntilPrayer > 0 { // 30 minutes
            return TimelineEntryRelevance(score: 1.0)
        }
        
        // Medium relevance within an hour
        if timeUntilPrayer <= 3600 && timeUntilPrayer > 0 { // 1 hour
            return TimelineEntryRelevance(score: 0.7)
        }
        
        return TimelineEntryRelevance(score: 0.3)
    }
    
    // MARK: - Private Methods
    
    private func scheduleBackgroundRefresh(at date: Date, reason: String) {
        // In a real implementation, this would integrate with Background Tasks
        // For now, we'll just log the scheduling
        print("📅 Scheduled widget background refresh for \(date) - Reason: \(reason)")
    }
}
