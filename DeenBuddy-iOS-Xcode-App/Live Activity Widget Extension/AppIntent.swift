//
//  AppIntent.swift
//  Live Activity Widget Extension
//
//  Created by Farhoud Talebi on 2025-08-01.
//

import Foundation
import WidgetKit
import AppIntents
import Intents
import OSLog

// MARK: - Prayer Widget Configuration Intent

@available(iOS 16.1, *)
class PrayerWidgetConfigurationIntent: INIntent, WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Prayer Widget Configuration" }
    static var description: IntentDescription { "Configure your DeenBuddy prayer widgets" }
    
    override class var supportsSecureCoding: Bool { true }

    // Show Arabic text in widgets
    @Parameter(title: "Show Arabic Text", default: true)
    var showArabicText: Bool
    
    // Show countdown timer
    @Parameter(title: "Show Countdown", default: true)
    var showCountdown: Bool
    
    // Widget theme preference
    @Parameter(title: "Theme", default: "auto")
    var theme: String
    
    required override init() {
        super.init()
        self.showArabicText = true
        self.showCountdown = true
        self.theme = "auto"
    }
    
    required override init?(coder: NSCoder) {
        super.init(coder: coder)
        self.showArabicText = coder.decodeBool(forKey: "showArabicText")
        self.showCountdown = coder.decodeBool(forKey: "showCountdown")
        self.theme = (coder.decodeObject(of: NSString.self, forKey: "theme") as String?) ?? "auto"
    }
    
    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(showArabicText, forKey: "showArabicText")
        coder.encode(showCountdown, forKey: "showCountdown")
        coder.encode(theme as NSString, forKey: "theme")
    }
    
    @available(iOSApplicationExtension 16.1, *)
    func perform() async throws -> some IntentResult {
        // Widget configuration is handled in the main app
        return .result()
    }
}

// MARK: - Live Activity Configuration Intent

@available(iOS 16.1, *)
struct LiveActivityConfigurationIntent: AppIntent {
    static var title: LocalizedStringResource { "Prayer Live Activity" }
    static var description: IntentDescription { "Start a live activity for prayer countdown" }
    
    // Show Arabic symbols in Live Activity
    @Parameter(title: "Show Arabic Symbols", default: true)
    var showArabicSymbols: Bool
    
    // Notification urgency level
    @Parameter(title: "Urgency Level", default: "normal")
    var urgencyLevel: String
    
    @available(iOSApplicationExtension 16.1, *)
    @MainActor
    func perform() async throws -> some IntentResult {
        // No-op in extension; starting Live Activities is handled in the main app.
        return .result()
    }
}

// MARK: - Prayer Completion Intent

@available(iOS 17.0, *)
enum PrayerIntentOption: String, CaseIterable, AppEnum {
    case fajr
    case dhuhr
    case asr
    case maghrib
    case isha

    init(prayer: Prayer) {
        guard let option = PrayerIntentOption(rawValue: prayer.rawValue) else {
            assertionFailure("PrayerIntentOption mismatch for raw value: \(prayer.rawValue)")
            self = .fajr
            return
        }
        self = option
    }

    var prayer: Prayer {
        guard let resolved = Prayer(rawValue: rawValue) else {
            assertionFailure("Prayer raw value mismatch for intent option: \(rawValue)")
            return .fajr
        }
        return resolved
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Prayer"
    }

    static var caseDisplayRepresentations: [PrayerIntentOption: DisplayRepresentation] {
        [
            .fajr: "Fajr",
            .dhuhr: "Dhuhr",
            .asr: "Asr",
            .maghrib: "Maghrib",
            .isha: "Isha"
        ]
    }
}

@available(iOS 17.0, *)
struct ConfirmPrayerCompletionIntent: AppIntent {
    static var title: LocalizedStringResource { "Mark Prayer Completed" }
    static var description = IntentDescription("Confirm that a prayer has been completed from the Live Activity.")

    @Parameter(title: "Prayer")
    var prayer: PrayerIntentOption

    func perform() async throws -> some IntentResult {
        PrayerCompletionIntentDispatcher.enqueueCompletion(
            prayerRawValue: prayer.rawValue,
            completedAt: Date(),
            source: "live_activity_intent"
        )

        return .result()
    }
}

@available(iOS 17.0, *)
extension ConfirmPrayerCompletionIntent {
    init(prayer: PrayerIntentOption) {
        self.init()
        self.prayer = prayer
    }
}

// MARK: - Local dispatcher (extension scope)

private enum PrayerCompletionIntentDispatcher {
    private static let appGroupIdentifier = "group.com.deenbuddy.app"
    private static let queueKey = "PrayerLiveActivityActionBridge.queue"
    private static let notificationName = "com.deenbuddy.app.prayerCompletion"
    private static let syncQueue = DispatchQueue(label: "com.deenbuddy.app.prayerCompletionQueue")
    private static let logger = Logger(subsystem: "com.deenbuddy.app", category: "PrayerCompletionIntent")

    // Queue management: prevent unbounded growth from unprocessed completions
    private static let maxQueueSize = 100        // ~20 days at 5 prayers/day
    private static let retentionPeriod: TimeInterval = 7 * 24 * 60 * 60  // 7 days

    static func enqueueCompletion(prayerRawValue: String, completedAt: Date, source: String) {
        syncQueue.sync {
            guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
                logger.error("Unable to access shared UserDefaults for prayer completion queue (appGroupIdentifier: \(appGroupIdentifier, privacy: .public))")
                return
            }

            var queue = loadQueue(from: defaults)

            // 1. Remove expired items (older than retention period)
            let cutoffDate = Date().addingTimeInterval(-retentionPeriod)
            queue = queue.filter { $0.completedAt >= cutoffDate }

            // 2. Enforce max size bound (remove oldest entries if at capacity)
            if queue.count >= maxQueueSize {
                let removeCount = queue.count - maxQueueSize + 1
                queue.removeFirst(removeCount)
            }

            // 3. Append new completion
            queue.append(PrayerCompletionAction(prayerRawValue: prayerRawValue, completedAt: completedAt, source: source))

            let data: Data
            do {
                data = try JSONEncoder().encode(queue)
            } catch {
                logger.error("Failed to encode prayer completion queue: \(error.localizedDescription, privacy: .public)")
                return
            }

            defaults.set(data, forKey: queueKey)
            postDarwinNotification()
        }
    }

    private static func loadQueue(from defaults: UserDefaults) -> [PrayerCompletionAction] {
        guard let data = defaults.data(forKey: queueKey) else { return [] }
        do {
            return try JSONDecoder().decode([PrayerCompletionAction].self, from: data)
        } catch {
            logger.error("Failed to decode prayer completion queue for key \(queueKey, privacy: .public): \(error.localizedDescription, privacy: .public)")
            defaults.removeObject(forKey: queueKey)
            return []
        }
    }

    private static func postDarwinNotification() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(notificationName as CFString),
            nil,
            nil,
            true
        )
    }
}

private struct PrayerCompletionAction: Codable {
    let prayerRawValue: String
    let completedAt: Date
    let source: String
}
