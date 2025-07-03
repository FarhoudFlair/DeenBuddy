import Foundation
import UIKit
import Combine

/// Service for managing iOS accessibility features
@MainActor
public class AccessibilityService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var isVoiceOverEnabled = false
    @Published public var isReduceMotionEnabled = false
    @Published public var isReduceTransparencyEnabled = false
    @Published public var isLargerTextEnabled = false
    @Published public var isBoldTextEnabled = false
    @Published public var isButtonShapesEnabled = false
    @Published public var isOnOffLabelsEnabled = false
    @Published public var preferredContentSizeCategory: UIContentSizeCategory = .medium
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let notificationCenter = NotificationCenter.default
    
    // MARK: - Initialization
    
    public init() {
        updateAccessibilitySettings()
        setupAccessibilityObservers()
    }
    
    // MARK: - Public Methods
    
    public func announceForAccessibility(_ message: String) {
        guard isVoiceOverEnabled else { return }
        
        UIAccessibility.post(notification: .announcement, argument: message)
    }
    
    public func announcePageChanged() {
        guard isVoiceOverEnabled else { return }
        
        UIAccessibility.post(notification: .pageScrolled, argument: nil)
    }
    
    public func announceLayoutChanged() {
        guard isVoiceOverEnabled else { return }
        
        UIAccessibility.post(notification: .layoutChanged, argument: nil)
    }
    
    public func focusOnElement(_ element: Any) {
        guard isVoiceOverEnabled else { return }
        
        UIAccessibility.post(notification: .layoutChanged, argument: element)
    }
    
    public func getAccessibilityLabel(for prayer: Prayer) -> String {
        let arabicName = getArabicName(for: prayer)
        return "\(prayer.displayName) prayer, \(arabicName)"
    }
    
    public func getAccessibilityHint(for prayer: Prayer) -> String {
        return "Tap to view \(prayer.displayName) prayer guide"
    }
    
    public func getPrayerTimeAccessibilityLabel(for prayerTime: PrayerTime) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let timeString = formatter.string(from: prayerTime.time)
        
        return "\(prayerTime.prayer.displayName) prayer at \(timeString)"
    }
    
    public func getCountdownAccessibilityLabel(timeRemaining: TimeInterval) -> String {
        let hours = Int(timeRemaining) / 3600
        let minutes = Int(timeRemaining) % 3600 / 60
        
        if hours > 0 {
            return "\(hours) hours and \(minutes) minutes until next prayer"
        } else {
            return "\(minutes) minutes until next prayer"
        }
    }
    
    public func shouldReduceMotion() -> Bool {
        return isReduceMotionEnabled
    }
    
    public func shouldReduceTransparency() -> Bool {
        return isReduceTransparencyEnabled
    }
    
    public func shouldUseLargerText() -> Bool {
        return isLargerTextEnabled
    }
    
    public func shouldUseBoldText() -> Bool {
        return isBoldTextEnabled
    }
    
    public func shouldShowButtonShapes() -> Bool {
        return isButtonShapesEnabled
    }
    
    public func shouldShowOnOffLabels() -> Bool {
        return isOnOffLabelsEnabled
    }
    
    public func getScaledFont(for textStyle: UIFont.TextStyle, maximumSize: CGFloat? = nil) -> UIFont {
        let font = UIFont.preferredFont(forTextStyle: textStyle)
        
        if let maximumSize = maximumSize {
            let scaledFont = UIFontMetrics(forTextStyle: textStyle).scaledFont(for: font, maximumPointSize: maximumSize)
            return scaledFont
        }
        
        return font
    }
    
    // MARK: - Private Methods
    
    private func updateAccessibilitySettings() {
        isVoiceOverEnabled = UIAccessibility.isVoiceOverRunning
        isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        isReduceTransparencyEnabled = UIAccessibility.isReduceTransparencyEnabled
        isLargerTextEnabled = UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory
        isBoldTextEnabled = UIAccessibility.isBoldTextEnabled
        isButtonShapesEnabled = UIAccessibility.isButtonShapesEnabled
        isOnOffLabelsEnabled = UIAccessibility.isOnOffSwitchLabelsEnabled
        preferredContentSizeCategory = UIApplication.shared.preferredContentSizeCategory
    }
    
    private func setupAccessibilityObservers() {
        // VoiceOver status changes
        notificationCenter.publisher(for: UIAccessibility.voiceOverStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.isVoiceOverEnabled = UIAccessibility.isVoiceOverRunning
            }
            .store(in: &cancellables)
        
        // Reduce motion changes
        notificationCenter.publisher(for: UIAccessibility.reduceMotionStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
            }
            .store(in: &cancellables)
        
        // Reduce transparency changes
        notificationCenter.publisher(for: UIAccessibility.reduceTransparencyStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.isReduceTransparencyEnabled = UIAccessibility.isReduceTransparencyEnabled
            }
            .store(in: &cancellables)
        
        // Bold text changes
        notificationCenter.publisher(for: UIAccessibility.boldTextStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.isBoldTextEnabled = UIAccessibility.isBoldTextEnabled
            }
            .store(in: &cancellables)
        
        // Button shapes changes
        notificationCenter.publisher(for: UIAccessibility.buttonShapesEnabledStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.isButtonShapesEnabled = UIAccessibility.isButtonShapesEnabled
            }
            .store(in: &cancellables)
        
        // On/Off labels changes
        notificationCenter.publisher(for: UIAccessibility.onOffSwitchLabelsDidChangeNotification)
            .sink { [weak self] _ in
                self?.isOnOffLabelsEnabled = UIAccessibility.isOnOffSwitchLabelsEnabled
            }
            .store(in: &cancellables)
        
        // Content size category changes
        notificationCenter.publisher(for: UIContentSizeCategory.didChangeNotification)
            .sink { [weak self] _ in
                self?.preferredContentSizeCategory = UIApplication.shared.preferredContentSizeCategory
                self?.isLargerTextEnabled = UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory
            }
            .store(in: &cancellables)
    }
    
    private func getArabicName(for prayer: Prayer) -> String {
        switch prayer {
        case .fajr:
            return "الفجر"
        case .dhuhr:
            return "الظهر"
        case .asr:
            return "العصر"
        case .maghrib:
            return "المغرب"
        case .isha:
            return "العشاء"
        }
    }
}

// MARK: - Accessibility Helpers

extension AccessibilityService {
    
    /// Create accessibility attributes for prayer guide content
    public func createPrayerGuideAccessibility(
        title: String,
        content: String,
        step: Int? = nil,
        totalSteps: Int? = nil
    ) -> (label: String, hint: String) {
        
        var label = title
        if let step = step, let totalSteps = totalSteps {
            label += ", step \(step) of \(totalSteps)"
        }
        
        let hint = "Double tap to read content. Swipe right to continue."
        
        return (label: label, hint: hint)
    }
    
    /// Create accessibility attributes for prayer time displays
    public func createPrayerTimeAccessibility(
        prayer: Prayer,
        time: Date,
        isNext: Bool = false
    ) -> (label: String, hint: String) {
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let timeString = formatter.string(from: time)
        
        var label = "\(prayer.displayName) prayer at \(timeString)"
        if isNext {
            label = "Next prayer: " + label
        }
        
        let hint = "Double tap to view prayer guide"
        
        return (label: label, hint: hint)
    }
    
    /// Create accessibility attributes for toggle buttons
    public func createToggleAccessibility(
        title: String,
        isOn: Bool,
        action: String
    ) -> (label: String, hint: String, value: String) {
        
        let label = title
        let value = isOn ? "On" : "Off"
        let hint = "Double tap to \(action)"
        
        return (label: label, hint: hint, value: value)
    }
}
