import Foundation
import UIKit

/// Service for providing haptic feedback on iOS devices
@MainActor
public class HapticFeedbackService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var isHapticsEnabled = true
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    private let settingsKey = "DeenAssist.HapticsEnabled"
    
    // MARK: - Haptic Generators
    
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()
    
    // MARK: - Haptic Types
    
    public enum HapticType {
        case light
        case medium
        case heavy
        case selection
        case success
        case warning
        case error
    }
    
    // MARK: - Initialization
    
    public init() {
        loadSettings()
        prepareHapticGenerators()
        setupSettingsObserver()
    }
    
    // MARK: - Public Methods
    
    public func playHaptic(_ type: HapticType) {
        guard isHapticsEnabled else { return }
        
        switch type {
        case .light:
            impactLight.impactOccurred()
            
        case .medium:
            impactMedium.impactOccurred()
            
        case .heavy:
            impactHeavy.impactOccurred()
            
        case .selection:
            selectionGenerator.selectionChanged()
            
        case .success:
            notificationGenerator.notificationOccurred(.success)
            
        case .warning:
            notificationGenerator.notificationOccurred(.warning)
            
        case .error:
            notificationGenerator.notificationOccurred(.error)
        }
    }
    
    // MARK: - Convenience Methods
    
    public func playButtonTap() {
        playHaptic(.light)
    }
    
    public func playToggleSwitch() {
        playHaptic(.medium)
    }
    
    public func playSelection() {
        playHaptic(.selection)
    }
    
    public func playSuccess() {
        playHaptic(.success)
    }
    
    public func playError() {
        playHaptic(.error)
    }
    
    public func playPrayerTimeAlert() {
        playHaptic(.medium)
    }
    
    public func playBookmarkToggle() {
        playHaptic(.light)
    }
    
    public func playNavigationTransition() {
        playHaptic(.selection)
    }
    
    public func playRefreshComplete() {
        playHaptic(.success)
    }
    
    public func playOfflineToggle() {
        playHaptic(.medium)
    }
    
    // MARK: - Settings
    
    public func setHapticsEnabled(_ enabled: Bool) {
        isHapticsEnabled = enabled
        userDefaults.set(enabled, forKey: settingsKey)
        
        if enabled {
            prepareHapticGenerators()
        }
    }
    
    // MARK: - Private Methods
    
    private func loadSettings() {
        if userDefaults.object(forKey: settingsKey) != nil {
            isHapticsEnabled = userDefaults.bool(forKey: settingsKey)
        } else {
            // Default to enabled
            isHapticsEnabled = true
            userDefaults.set(true, forKey: settingsKey)
        }
    }
    
    private func setupSettingsObserver() {
        $isHapticsEnabled
            .sink { [weak self] enabled in
                self?.userDefaults.set(enabled, forKey: self?.settingsKey ?? "")
                if enabled {
                    self?.prepareHapticGenerators()
                }
            }
            .store(in: &cancellables)
    }
    
    private func prepareHapticGenerators() {
        guard isHapticsEnabled else { return }
        
        // Prepare all generators for better performance
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        notificationGenerator.prepare()
        selectionGenerator.prepare()
    }
    
    private var cancellables = Set<AnyCancellable>()
}

// MARK: - Haptic Feedback Extensions

extension HapticFeedbackService {
    
    /// Play haptic feedback for prayer-related actions
    public func playPrayerHaptic(for action: PrayerAction) {
        switch action {
        case .timeAlert:
            playPrayerTimeAlert()
        case .guideOpened:
            playSelection()
        case .stepCompleted:
            playSuccess()
        case .bookmarkToggled:
            playBookmarkToggle()
        case .offlineToggled:
            playOfflineToggle()
        }
    }
    
    /// Play haptic feedback for UI interactions
    public func playUIHaptic(for interaction: UIInteraction) {
        switch interaction {
        case .buttonTap:
            playButtonTap()
        case .toggleSwitch:
            playToggleSwitch()
        case .tabSelection:
            playSelection()
        case .navigationTransition:
            playNavigationTransition()
        case .refreshComplete:
            playRefreshComplete()
        case .errorOccurred:
            playError()
        }
    }
}

// MARK: - Supporting Enums

extension HapticFeedbackService {
    
    public enum PrayerAction {
        case timeAlert
        case guideOpened
        case stepCompleted
        case bookmarkToggled
        case offlineToggled
    }
    
    public enum UIInteraction {
        case buttonTap
        case toggleSwitch
        case tabSelection
        case navigationTransition
        case refreshComplete
        case errorOccurred
    }
}

// MARK: - Import Combine

import Combine
