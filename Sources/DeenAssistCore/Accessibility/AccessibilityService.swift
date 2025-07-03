import Foundation
import UIKit
import Combine

/// Service for managing accessibility features and compliance
@MainActor
public class AccessibilityService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var isVoiceOverEnabled = false
    @Published public var isReduceMotionEnabled = false
    @Published public var isReduceTransparencyEnabled = false
    @Published public var isInvertColorsEnabled = false
    @Published public var preferredContentSizeCategory: UIContentSizeCategory = .medium
    @Published public var isHighContrastEnabled = false
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Singleton
    
    public static let shared = AccessibilityService()
    
    private init() {
        setupAccessibilityObservers()
        updateAccessibilitySettings()
    }
    
    // MARK: - Public Methods
    
    /// Check if any accessibility features are enabled
    public var hasAccessibilityFeaturesEnabled: Bool {
        return isVoiceOverEnabled || 
               isReduceMotionEnabled || 
               isReduceTransparencyEnabled || 
               isInvertColorsEnabled ||
               isHighContrastEnabled ||
               preferredContentSizeCategory.isAccessibilityCategory
    }
    
    /// Get accessibility-friendly animation duration
    public func getAnimationDuration(_ defaultDuration: TimeInterval) -> TimeInterval {
        return isReduceMotionEnabled ? 0.0 : defaultDuration
    }
    
    /// Get accessibility-friendly opacity
    public func getOpacity(_ defaultOpacity: Double) -> Double {
        return isReduceTransparencyEnabled ? 1.0 : defaultOpacity
    }
    
    /// Get accessibility-friendly font size multiplier
    public var fontSizeMultiplier: CGFloat {
        switch preferredContentSizeCategory {
        case .extraSmall: return 0.8
        case .small: return 0.9
        case .medium: return 1.0
        case .large: return 1.1
        case .extraLarge: return 1.2
        case .extraExtraLarge: return 1.3
        case .extraExtraExtraLarge: return 1.4
        case .accessibilityMedium: return 1.6
        case .accessibilityLarge: return 1.8
        case .accessibilityExtraLarge: return 2.0
        case .accessibilityExtraExtraLarge: return 2.2
        case .accessibilityExtraExtraExtraLarge: return 2.4
        default: return 1.0
        }
    }
    
    /// Get accessibility summary for debugging
    public func getAccessibilitySummary() -> AccessibilitySummary {
        return AccessibilitySummary(
            isVoiceOverEnabled: isVoiceOverEnabled,
            isReduceMotionEnabled: isReduceMotionEnabled,
            isReduceTransparencyEnabled: isReduceTransparencyEnabled,
            isInvertColorsEnabled: isInvertColorsEnabled,
            isHighContrastEnabled: isHighContrastEnabled,
            preferredContentSizeCategory: preferredContentSizeCategory,
            fontSizeMultiplier: fontSizeMultiplier,
            hasAccessibilityFeaturesEnabled: hasAccessibilityFeaturesEnabled
        )
    }
    
    /// Announce text to VoiceOver
    public func announceToVoiceOver(_ text: String, priority: UIAccessibility.AnnouncementPriority = .medium) {
        guard isVoiceOverEnabled else { return }
        
        UIAccessibility.post(notification: .announcement, argument: text)
        
        print("🔊 VoiceOver announcement: \(text)")
    }
    
    /// Post layout change notification
    public func postLayoutChangeNotification() {
        UIAccessibility.post(notification: .layoutChanged, argument: nil)
    }
    
    /// Post screen change notification
    public func postScreenChangeNotification(focusElement: Any? = nil) {
        UIAccessibility.post(notification: .screenChanged, argument: focusElement)
    }
    
    // MARK: - Private Methods
    
    private func setupAccessibilityObservers() {
        // VoiceOver
        NotificationCenter.default.publisher(for: UIAccessibility.voiceOverStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.updateAccessibilitySettings()
            }
            .store(in: &cancellables)
        
        // Reduce Motion
        NotificationCenter.default.publisher(for: UIAccessibility.reduceMotionStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.updateAccessibilitySettings()
            }
            .store(in: &cancellables)
        
        // Reduce Transparency
        NotificationCenter.default.publisher(for: UIAccessibility.reduceTransparencyStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.updateAccessibilitySettings()
            }
            .store(in: &cancellables)
        
        // Invert Colors
        NotificationCenter.default.publisher(for: UIAccessibility.invertColorsStatusDidChangeNotification)
            .sink { [weak self] _ in
                self?.updateAccessibilitySettings()
            }
            .store(in: &cancellables)
        
        // Content Size Category
        NotificationCenter.default.publisher(for: UIContentSizeCategory.didChangeNotification)
            .sink { [weak self] _ in
                self?.updateAccessibilitySettings()
            }
            .store(in: &cancellables)
        
        // High Contrast (iOS 13+)
        if #available(iOS 13.0, *) {
            NotificationCenter.default.publisher(for: UIAccessibility.darkerSystemColorsStatusDidChangeNotification)
                .sink { [weak self] _ in
                    self?.updateAccessibilitySettings()
                }
                .store(in: &cancellables)
        }
    }
    
    private func updateAccessibilitySettings() {
        isVoiceOverEnabled = UIAccessibility.isVoiceOverRunning
        isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        isReduceTransparencyEnabled = UIAccessibility.isReduceTransparencyEnabled
        isInvertColorsEnabled = UIAccessibility.isInvertColorsEnabled
        preferredContentSizeCategory = UIApplication.shared.preferredContentSizeCategory
        
        if #available(iOS 13.0, *) {
            isHighContrastEnabled = UIAccessibility.isDarkerSystemColorsEnabled
        }
        
        print("♿ Accessibility settings updated: VoiceOver=\(isVoiceOverEnabled), ReduceMotion=\(isReduceMotionEnabled)")
    }
}

// MARK: - Accessibility Summary

public struct AccessibilitySummary {
    public let isVoiceOverEnabled: Bool
    public let isReduceMotionEnabled: Bool
    public let isReduceTransparencyEnabled: Bool
    public let isInvertColorsEnabled: Bool
    public let isHighContrastEnabled: Bool
    public let preferredContentSizeCategory: UIContentSizeCategory
    public let fontSizeMultiplier: CGFloat
    public let hasAccessibilityFeaturesEnabled: Bool
    
    public var description: String {
        var features: [String] = []
        
        if isVoiceOverEnabled { features.append("VoiceOver") }
        if isReduceMotionEnabled { features.append("Reduce Motion") }
        if isReduceTransparencyEnabled { features.append("Reduce Transparency") }
        if isInvertColorsEnabled { features.append("Invert Colors") }
        if isHighContrastEnabled { features.append("High Contrast") }
        if preferredContentSizeCategory.isAccessibilityCategory { features.append("Large Text") }
        
        return features.isEmpty ? "No accessibility features enabled" : "Enabled: \(features.joined(separator: ", "))"
    }
}

// MARK: - Accessibility Helpers

public struct AccessibilityHelpers {
    
    /// Create accessibility label for prayer time
    public static func prayerTimeLabel(prayer: Prayer, time: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(prayer.displayName) prayer at \(formatter.string(from: time))"
    }
    
    /// Create accessibility label for Qibla direction
    public static func qiblaDirectionLabel(direction: Double, distance: Double) -> String {
        let directionText = compassDirectionText(for: direction)
        let distanceText = String(format: "%.0f kilometers", distance)
        return "Qibla direction: \(directionText), distance: \(distanceText)"
    }
    
    /// Create accessibility label for prayer guide step
    public static func prayerGuideStepLabel(step: Int, total: Int, title: String) -> String {
        return "Step \(step) of \(total): \(title)"
    }
    
    /// Create accessibility hint for interactive elements
    public static func interactionHint(action: String) -> String {
        return "Double tap to \(action)"
    }
    
    /// Convert compass direction to text
    private static func compassDirectionText(for degrees: Double) -> String {
        let directions = [
            "North", "North Northeast", "Northeast", "East Northeast",
            "East", "East Southeast", "Southeast", "South Southeast",
            "South", "South Southwest", "Southwest", "West Southwest",
            "West", "West Northwest", "Northwest", "North Northwest"
        ]
        
        let index = Int((degrees + 11.25) / 22.5) % 16
        return directions[index]
    }
}

// MARK: - SwiftUI Accessibility Extensions

public extension View {
    /// Apply accessibility settings from AccessibilityService
    func accessibilityOptimized() -> some View {
        let service = AccessibilityService.shared
        
        return self
            .animation(
                .easeInOut(duration: service.getAnimationDuration(0.3)),
                value: service.isReduceMotionEnabled
            )
    }
    
    /// Add prayer time accessibility
    func prayerTimeAccessibility(prayer: Prayer, time: Date) -> some View {
        self
            .accessibilityLabel(AccessibilityHelpers.prayerTimeLabel(prayer: prayer, time: time))
            .accessibilityAddTraits(.isButton)
    }
    
    /// Add Qibla compass accessibility
    func qiblaCompassAccessibility(direction: Double, distance: Double) -> some View {
        self
            .accessibilityLabel(AccessibilityHelpers.qiblaDirectionLabel(direction: direction, distance: distance))
            .accessibilityAddTraits(.updatesFrequently)
    }
    
    /// Add prayer guide step accessibility
    func prayerGuideStepAccessibility(step: Int, total: Int, title: String, action: String) -> some View {
        self
            .accessibilityLabel(AccessibilityHelpers.prayerGuideStepLabel(step: step, total: total, title: title))
            .accessibilityHint(AccessibilityHelpers.interactionHint(action: action))
            .accessibilityAddTraits(.isButton)
    }
    
    /// Add custom accessibility announcement
    func accessibilityAnnouncement(_ text: String, priority: UIAccessibility.AnnouncementPriority = .medium) -> some View {
        self.onAppear {
            AccessibilityService.shared.announceToVoiceOver(text, priority: priority)
        }
    }
}
