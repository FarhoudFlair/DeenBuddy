import Foundation
import ActivityKit
import UIKit
import UserNotifications
import WidgetKit

// MARK: - Smart Refresh Manager for Battery Optimization

@available(iOS 16.1, *)
class SmartRefreshManager: ObservableObject {
    
    static let shared = SmartRefreshManager()
    
    @Published var currentStrategy: RefreshStrategy = .intelligent
    @Published var batteryLevel: Float = 1.0
    @Published var refreshCount: Int = 0
    
    private var refreshTimer: Timer?
    private let maxDailyRefreshes = 144 // Every 10 minutes max per day
    private let criticalBatteryThreshold: Float = 0.20
    private let lowBatteryThreshold: Float = 0.30
    private let highBatteryThreshold: Float = 0.80
    private let adaptiveLowBatteryThreshold: Float = 0.4
    private let adaptiveHighBatteryThreshold: Float = 0.7
    private let fallbackBatteryLevelCharging: Float = 0.8
    private let fallbackBatteryLevelUnknown: Float = 0.5
    private let batteryLevelThreshold: Float = 0.5
    private var lastRefreshResetDate: Date = Date()
    
    private init() {
        setupBatteryMonitoring()
        determineOptimalStrategy()
        resetRefreshCountIfNeeded()
    }
    
    // MARK: - Refresh Strategies
    
    enum RefreshStrategy {
        case aggressive      // Every 30 seconds (high battery, imminent prayer)
        case normal          // Every 1 minute (normal conditions)  
        case conservative    // Every 5 minutes (low battery)
        case minimal         // Every 15 minutes (critical battery)
        case intelligent     // Adaptive based on context
        case prayerAligned   // Only at strategic prayer time intervals
    }
    
    // MARK: - Smart Refresh Logic
    
    func scheduleSmartRefresh(for activity: Activity<PrayerCountdownActivity>) {
        // Cancel any existing timers (timers are unreliable in widget extensions)
        cancelCurrentRefresh()

        let strategy = determineOptimalStrategy()
        let interval = refreshInterval(for: strategy, activity: activity)
        let preferredDate = Date().addingTimeInterval(interval)

        print("🔋 Smart Refresh: Using \(strategy) strategy; scheduling preferred refresh at \(preferredDate)")

        // Ask the system to refresh the Live Activity content around the preferred date
        if #available(iOS 16.2, *) {
            let currentState = activity.contentState
            Task {
                await activity.update(.init(state: currentState, staleDate: preferredDate))
            }
        }

        // Optionally request widget timeline reloads for server-driven/widget updates
        // (Safe no-op if no widgets are present)
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    private func performSmartRefresh(activity: Activity<PrayerCountdownActivity>) async {
        // Reset refresh count if calendar day has changed
        resetRefreshCountIfNeeded()
        
        guard refreshCount < maxDailyRefreshes else {
            print("⚠️ Daily refresh limit reached, skipping update")
            return
        }
        
        guard shouldRefreshNow(activity: activity) else {
            print("⏭️ Skipping refresh - not optimal time")
            return
        }
        
        // Generate new state and update the activity
        let newState = await generateUpdatedState(from: activity.contentState)
        if #available(iOS 16.2, *) {
            await activity.update(.init(state: newState, staleDate: nil))
        }
        
        refreshCount += 1
        print("✅ Smart refresh completed (\(refreshCount)/\(maxDailyRefreshes))")
        
        // Adjust strategy if needed
        if refreshCount % 10 == 0 {
            await adjustStrategyBasedOnUsage()
        }
    }
    
    // MARK: - Strategy Determination
    
    @discardableResult
    private func determineOptimalStrategy() -> RefreshStrategy {
        let batteryLevel = UIDevice.current.batteryLevel
        let batteryState = UIDevice.current.batteryState
        
        // Handle invalid battery level (< 0 means monitoring unavailable)
        if batteryLevel < 0 {
            // Battery level unknown - use charging state as fallback
            if batteryState == .charging {
                currentStrategy = .intelligent
                return .intelligent
            } else {
                // Unknown battery, not charging - use normal strategy
                currentStrategy = .normal
                return .normal
            }
        }
        
        // Critical battery - minimize refreshes
        if batteryLevel < criticalBatteryThreshold && batteryState != .charging {
            currentStrategy = .minimal
            return .minimal
        }
        
        // Low battery - reduce refreshes
        if batteryLevel < lowBatteryThreshold && batteryState != .charging {
            currentStrategy = .conservative
            return .conservative
        }
        
        // High battery or charging - more responsive
        if batteryLevel > highBatteryThreshold || batteryState == .charging {
            currentStrategy = .intelligent
            return .intelligent
        }
        
        // Default to normal
        currentStrategy = .normal
        return .normal
    }
    
    private func refreshInterval(for strategy: RefreshStrategy, activity: Activity<PrayerCountdownActivity>) -> TimeInterval {
        let timeUntilPrayer: TimeInterval = if #available(iOS 16.2, *) {
            activity.content.state.timeRemaining
        } else {
            activity.contentState.timeRemaining
        }
        
        switch strategy {
        case .aggressive:
            return 30 // 30 seconds
            
        case .normal:
            return timeUntilPrayer < 300 ? 30 : 60 // 30s if within 5 minutes, else 1 minute
            
        case .conservative:
            return timeUntilPrayer < 600 ? 120 : 300 // 2 minutes if within 10 minutes, else 5 minutes
            
        case .minimal:
            return 900 // 15 minutes
            
        case .intelligent:
            return adaptiveInterval(timeUntilPrayer: timeUntilPrayer)
            
        case .prayerAligned:
            return prayerAlignedInterval(timeUntilPrayer: timeUntilPrayer)
        }
    }
    
    private func adaptiveInterval(timeUntilPrayer: TimeInterval) -> TimeInterval {
        // Handle invalid battery level (< 0 means monitoring unavailable)
        let effectiveBatteryLevel: Float
        if batteryLevel >= 0 {
            effectiveBatteryLevel = batteryLevel
        } else {
            // Battery level unknown - check charging state
            let batteryState = UIDevice.current.batteryState
            effectiveBatteryLevel = (batteryState == .charging) ? fallbackBatteryLevelCharging : fallbackBatteryLevelUnknown
        }
        
        switch timeUntilPrayer {
        case 0..<300:        // Less than 5 minutes - very frequent
            return effectiveBatteryLevel > batteryLevelThreshold ? 30 : 60
        case 300..<900:      // 5-15 minutes - frequent
            return effectiveBatteryLevel > batteryLevelThreshold ? 60 : 120
        case 900..<1800:     // 15-30 minutes - moderate
            return effectiveBatteryLevel > batteryLevelThreshold ? 120 : 300
        default:             // More than 30 minutes - infrequent
            return effectiveBatteryLevel > batteryLevelThreshold ? 300 : 600
        }
    }
    
    private func prayerAlignedInterval(timeUntilPrayer: TimeInterval) -> TimeInterval {
        // Align refreshes with Islamic significance
        switch timeUntilPrayer {
        case 0..<60:         // Last minute - every 10 seconds
            return 10
        case 60..<300:       // Last 5 minutes - every minute
            return 60
        case 300..<1800:     // Last 30 minutes - every 5 minutes
            return 300
        default:             // More than 30 minutes - every 10 minutes
            return 600
        }
    }
    
    // MARK: - Smart Decision Making
    
    private func shouldRefreshNow(activity: Activity<PrayerCountdownActivity>) -> Bool {
        let timeUntilPrayer: TimeInterval = if #available(iOS 16.2, *) {
            activity.content.state.timeRemaining
        } else {
            activity.contentState.timeRemaining
        }
        
        // Always refresh if prayer is imminent (within 2 minutes)
        if timeUntilPrayer < 120 {
            return true
        }
        
        // Skip refresh if battery is critical and prayer is far away
        // Only check battery level if monitoring is available (batteryLevel >= 0)
        if batteryLevel >= 0 && batteryLevel < criticalBatteryThreshold && timeUntilPrayer > 1800 {
            return false
        }
        
        // Skip refresh during typical sleep hours (11 PM - 4 AM) unless it's Fajr
        let hour = Calendar.current.component(.hour, from: Date())
        let nextPrayer = if #available(iOS 16.2, *) {
            activity.content.state.nextPrayer
        } else {
            activity.contentState.nextPrayer
        }
        if (hour >= 23 || hour < 4) && nextPrayer != .fajr {
            return timeUntilPrayer < 600 // Only refresh if within 10 minutes
        }
        
        return true
    }
    
    // MARK: - Battery Optimization
    
    private func setupBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.batteryLevel = UIDevice.current.batteryLevel
            self?.determineOptimalStrategy()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.determineOptimalStrategy()
        }
    }
    
    private func adjustStrategyBasedOnUsage() async {
        let averageRefreshesPerHour = Double(refreshCount) / (Date().timeIntervalSince1970 / 3600)
        
        // Skip battery-based adjustments if battery level is unknown (< 0)
        guard batteryLevel >= 0 else {
            return
        }
        
        // If we're refreshing too frequently for the battery level, become more conservative
        if averageRefreshesPerHour > 10 && batteryLevel < adaptiveLowBatteryThreshold {
            currentStrategy = .conservative
        }
        
        // If battery is good and we haven't been refreshing much, become more responsive
        if averageRefreshesPerHour < 2 && batteryLevel > adaptiveHighBatteryThreshold {
            currentStrategy = .intelligent
        }
    }
    
    // MARK: - State Management
    
    private func generateUpdatedState(from currentState: PrayerCountdownActivity.ContentState) async -> PrayerCountdownActivity.ContentState {
        // Generate fresh prayer time data (placeholder logic)
        let updatedTimeRemaining = await calculateFreshTimeRemaining()
        
        return PrayerCountdownActivity.ContentState(
            nextPrayer: currentState.nextPrayer,
            prayerTime: currentState.prayerTime,
            timeRemaining: updatedTimeRemaining,
            location: currentState.location,
            hijriDate: currentState.hijriDate,
            calculationMethod: currentState.calculationMethod
        )
    }
    
    private func calculateFreshTimeRemaining() async -> TimeInterval {
        // Implement actual prayer time calculation
        return TimeInterval.random(in: 0...7200) // 0-2 hours for demo
    }
    
    // Reset daily refresh count if the calendar day has changed
    private func resetRefreshCountIfNeeded() {
        let calendar = Calendar.current
        if !calendar.isDateInToday(lastRefreshResetDate) {
            refreshCount = 0
            lastRefreshResetDate = Date()
            print("🔄 Daily refresh count reset")
        }
    }
    
    // MARK: - Cleanup
    
    private func cancelCurrentRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    deinit {
        cancelCurrentRefresh()
        NotificationCenter.default.removeObserver(self)
    }
}

// Background task APIs are not available in application extensions; removed for widget target.
