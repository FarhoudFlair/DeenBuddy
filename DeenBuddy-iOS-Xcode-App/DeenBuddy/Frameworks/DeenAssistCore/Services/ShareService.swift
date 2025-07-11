import Foundation
import UIKit
import SwiftUI

/// Service for sharing content on iOS
@MainActor
public class ShareService: ObservableObject {
    
    // MARK: - Share Content Types
    
    public enum ShareContent {
        case prayerGuide(title: String, content: String)
        case prayerTimes(times: [PrayerTime], location: String)
        case appRecommendation
        case verse(text: String, reference: String)
        case custom(title: String, text: String, url: URL?)
    }
    
    // MARK: - Public Methods
    
    public func shareContent(_ content: ShareContent, from sourceView: UIView? = nil) {
        let shareItems = createShareItems(for: content)
        presentShareSheet(with: shareItems, from: sourceView)
    }
    
    public func shareContent(_ content: ShareContent, from sourceRect: CGRect, in view: UIView) {
        let shareItems = createShareItems(for: content)
        presentShareSheet(with: shareItems, from: sourceRect, in: view)
    }
    
    public func sharePrayerGuide(
        title: String,
        content: String,
        from sourceView: UIView? = nil
    ) {
        let shareData = ShareContent.prayerGuide(title: title, content: content)
        shareContent(shareData, from: sourceView)
    }
    
    public func sharePrayerTimes(
        times: [PrayerTime],
        location: String,
        from sourceView: UIView? = nil
    ) {
        let shareData = ShareContent.prayerTimes(times: times, location: location)
        shareContent(shareData, from: sourceView)
    }
    
    public func shareAppRecommendation(from sourceView: UIView? = nil) {
        shareContent(.appRecommendation, from: sourceView)
    }
    
    // MARK: - Private Methods
    
    private func createShareItems(for content: ShareContent) -> [Any] {
        switch content {
        case .prayerGuide(let title, let content):
            return createPrayerGuideShareItems(title: title, content: content)
            
        case .prayerTimes(let times, let location):
            return createPrayerTimesShareItems(times: times, location: location)
            
        case .appRecommendation:
            return createAppRecommendationShareItems()
            
        case .verse(let text, let reference):
            return createVerseShareItems(text: text, reference: reference)
            
        case .custom(let title, let text, let url):
            return createCustomShareItems(title: title, text: text, url: url)
        }
    }
    
    private func createPrayerGuideShareItems(title: String, content: String) -> [Any] {
        let shareText = """
        📿 \(title)
        
        \(content)
        
        Shared from DeenBuddy - Your Islamic Prayer Companion
        """
        
        return [shareText]
    }
    
    private func createPrayerTimesShareItems(times: [PrayerTime], location: String) -> [Any] {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        let timesText = times.map { prayerTime in
            "\(prayerTime.prayer.displayName): \(formatter.string(from: prayerTime.time))"
        }.joined(separator: "\n")
        
        let shareText = """
        🕌 Prayer Times for \(location)
        
        \(timesText)
        
        Shared from DeenBuddy - Your Islamic Prayer Companion
        """
        
        return [shareText]
    }
    
    private func createAppRecommendationShareItems() -> [Any] {
        let shareText = """
        🕌 I'm using DeenBuddy for my daily prayers!
        
        It's a beautiful Islamic prayer companion that helps with:
        • Accurate prayer times for any location
        • Step-by-step prayer guides
        • Prayer reminders and notifications
        • Works offline too!
        
        Download it and join me in strengthening our faith together! 🤲
        """
        
        // Add App Store URL when available
        if let appStoreURL = URL(string: "https://apps.apple.com/app/deenbuddy") {
            return [shareText, appStoreURL]
        }
        
        return [shareText]
    }
    
    private func createVerseShareItems(text: String, reference: String) -> [Any] {
        let shareText = """
        📖 \(text)
        
        - \(reference)
        
        Shared from DeenBuddy - Your Islamic Prayer Companion
        """
        
        return [shareText]
    }
    
    private func createCustomShareItems(title: String, text: String, url: URL?) -> [Any] {
        let shareText = """
        \(title)
        
        \(text)
        
        Shared from DeenBuddy - Your Islamic Prayer Companion
        """
        
        var items: [Any] = [shareText]
        if let url = url {
            items.append(url)
        }
        
        return items
    }
    
    private func presentShareSheet(with items: [Any], from sourceView: UIView?) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            print("❌ Could not find root view controller for share sheet")
            return
        }
        
        let activityViewController = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        
        // Configure for iPad
        if let popover = activityViewController.popoverPresentationController {
            if let sourceView = sourceView {
                popover.sourceView = sourceView
                popover.sourceRect = sourceView.bounds
            } else {
                popover.sourceView = window
                popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
        }
        
        // Exclude certain activity types if needed
        activityViewController.excludedActivityTypes = [
            .assignToContact,
            .saveToCameraRoll,
            .addToReadingList
        ]
        
        rootViewController.present(activityViewController, animated: true)
    }
    
    private func presentShareSheet(with items: [Any], from sourceRect: CGRect, in view: UIView) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            print("❌ Could not find root view controller for share sheet")
            return
        }
        
        let activityViewController = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        
        // Configure for iPad
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = sourceRect
        }
        
        // Exclude certain activity types if needed
        activityViewController.excludedActivityTypes = [
            .assignToContact,
            .saveToCameraRoll,
            .addToReadingList
        ]
        
        rootViewController.present(activityViewController, animated: true)
    }
}

// MARK: - SwiftUI Integration

extension ShareService {
    
    /// Create a share sheet for SwiftUI views
    public func createShareSheet(for content: ShareContent) -> UIActivityViewController {
        let items = createShareItems(for: content)
        let activityViewController = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        
        activityViewController.excludedActivityTypes = [
            .assignToContact,
            .saveToCameraRoll,
            .addToReadingList
        ]
        
        return activityViewController
    }
}
