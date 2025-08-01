//
//  AppIntent.swift
//  Live Activity Widget Extension
//
//  Created by Farhoud Talebi on 2025-08-01.
//

import WidgetKit
import AppIntents

// MARK: - Prayer Widget Configuration Intent

struct PrayerWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Prayer Widget Configuration" }
    static var description: IntentDescription { "Configure your DeenBuddy prayer widgets" }

    // Show Arabic text in widgets
    @Parameter(title: "Show Arabic Text", default: true)
    var showArabicText: Bool
    
    // Show countdown timer
    @Parameter(title: "Show Countdown", default: true)
    var showCountdown: Bool
    
    // Widget theme preference
    @Parameter(title: "Theme", default: "auto")
    var theme: String
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
    
    func perform() async throws -> some IntentResult {
        // This would be implemented to start live activities
        // For now, just return success
        return .result()
    }
}
