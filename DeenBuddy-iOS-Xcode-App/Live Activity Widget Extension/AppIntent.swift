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
final class PrayerWidgetConfigurationIntent: INIntent, WidgetConfigurationIntent {
    nonisolated static var title: LocalizedStringResource { "Prayer Widget Configuration" }
    nonisolated static var description: IntentDescription { "Configure your DeenBuddy prayer widgets" }
    
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
    
    nonisolated required override init() {
        super.init()
        self.showArabicText = true
        self.showCountdown = true
        self.theme = "auto"
    }
    
    nonisolated required init?(coder: NSCoder) {
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

// Silence strict Sendable checks for generated Intent class
@available(iOS 16.1, *)
extension PrayerWidgetConfigurationIntent: @unchecked Sendable {}

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

    private static let logger = Logger(subsystem: "com.deenbuddy.app", category: "PrayerIntentOption")

    init?(prayer: Prayer) {
        guard let option = PrayerIntentOption(rawValue: prayer.rawValue) else {
            Self.logger.error("Unable to map prayer raw value \(prayer.rawValue, privacy: .public) to PrayerIntentOption")
            assertionFailure("PrayerIntentOption mismatch for raw value: \(prayer.rawValue)")
            return nil
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
        await PrayerCompletionIntentDispatcher.enqueueCompletion(
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
    private static let logger = Logger(subsystem: "com.deenbuddy.app", category: "PrayerCompletionIntent")

    static func enqueueCompletion(prayerRawValue: String, completedAt: Date, source: String) async {
        guard let prayer = Prayer(rawValue: prayerRawValue) else {
            logger.error("Received unknown prayer raw value: \(prayerRawValue, privacy: .public)")
            return
        }

        let success = await MainActor.run {
            PrayerLiveActivityActionBridge.shared.enqueueCompletion(
                prayer: prayer,
                completedAt: completedAt,
                source: source
            )
        }

        if !success {
            logger.error("Failed to enqueue completion for \(prayer.rawValue, privacy: .public) via \(source, privacy: .public)")
        }
    }
}
