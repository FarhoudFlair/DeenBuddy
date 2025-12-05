//
//  AppLaunchActivity.swift
//  DeenAssistCore
//
//  Created by Claude Code on 2025-07-28.
//

import Foundation
import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - App Launch Live Activity

@available(iOS 16.1, *)
public struct AppLaunchActivity: ActivityAttributes {
    
    // MARK: - Content State
    
    public struct ContentState: Codable, Hashable {
        public let greeting: String
        public let subGreeting: String
        public let isLoading: Bool
        public let progress: Double
        
        public init(
            greeting: String = "بسم الله",
            subGreeting: String = "Welcome to DeenBuddy",
            isLoading: Bool = true,
            progress: Double = 0.0
        ) {
            self.greeting = greeting
            self.subGreeting = subGreeting
            self.isLoading = isLoading
            self.progress = progress
        }
    }
    
    // Fixed attributes that don't change during the activity
    public let launchId: String
    public let startTime: Date
    public let appVersion: String?
    
    public init(launchId: String = UUID().uuidString, startTime: Date = Date(), appVersion: String? = nil) {
        self.launchId = launchId
        self.startTime = startTime
        self.appVersion = appVersion
    }
}

// MARK: - App Launch Live Activity Manager

@available(iOS 16.1, *)
public class AppLaunchLiveActivityManager: ObservableObject {
    
    // MARK: - Singleton
    
    public static let shared = AppLaunchLiveActivityManager()
    
    private init() {}
    
    // MARK: - Properties
    
    @Published public var currentActivity: Activity<AppLaunchActivity>?
    @Published public var isActivityActive: Bool = false
    
    // MARK: - Activity Management
    
    /// Start the app launch Live Activity with Allah symbol
    public func startAppLaunchActivity() async throws {
        
        // End any existing activity first
        await endCurrentActivity()
        
        let initialContentState = AppLaunchActivity.ContentState(
            greeting: "الله",
            subGreeting: "بسم الله الرحمن الرحيم",
            isLoading: true,
            progress: 0.1
        )
        
        let activityAttributes = AppLaunchActivity(
            launchId: "app_launch_\(Date().timeIntervalSince1970)",
            startTime: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        )
        
        do {
            // Check if Live Activities are available before attempting to start
            guard isLiveActivityAvailable else {
                print("⚠️ Live Activities not available for app launch")
                return
            }

            let activity = try Activity.request(
                attributes: activityAttributes,
                contentState: initialContentState,
                pushType: nil // No push notifications needed for launch activity
            )

            await MainActor.run {
                self.currentActivity = activity
                self.isActivityActive = true
            }

            print("✅ Started App Launch Live Activity with Allah symbol")

            // Schedule brief display duration
            scheduleAppLaunchCompletion(for: activity)

        } catch {
            print("❌ Failed to start App Launch Live Activity: \(error)")
            
            // Don't throw error for launch activity - it's not critical
            // Just log the failure and continue app launch
            let errorDescription = error.localizedDescription.lowercased()
            if errorDescription.contains("permission") || errorDescription.contains("not enabled") {
                print("ℹ️ Live Activities permission not granted - continuing without launch activity")
            }
        }
    }
    
    /// Update the app launch activity with loading progress
    public func updateAppLaunchProgress(
        greeting: String? = nil,
        subGreeting: String? = nil,
        progress: Double,
        isLoading: Bool = true
    ) async {
        guard let activity = currentActivity else { return }
        
        let currentState = activity.contentState
        let updatedState = AppLaunchActivity.ContentState(
            greeting: greeting ?? currentState.greeting,
            subGreeting: subGreeting ?? currentState.subGreeting,
            isLoading: isLoading,
            progress: progress
        )

        await activity.update(using: updatedState)
        print("🔄 Updated App Launch Activity: \(Int(progress * 100))%")
    }
    
    /// End the app launch Live Activity
    public func endCurrentActivity() async {
        guard let activity = currentActivity else { return }
        
        let finalState = AppLaunchActivity.ContentState(
            greeting: "الله",
            subGreeting: "DeenBuddy Ready",
            isLoading: false,
            progress: 1.0
        )
        
        // Keep the activity visible for just 2 seconds after completion
        await activity.end(using: finalState, dismissalPolicy: .after(Date().addingTimeInterval(2)))
        
        await MainActor.run {
            self.currentActivity = nil
            self.isActivityActive = false
        }

        print("✅ Ended App Launch Live Activity")
    }
    
    /// Check if Live Activities are available and enabled
    public var isLiveActivityAvailable: Bool {
        return ActivityAuthorizationInfo().areActivitiesEnabled
    }
    
    // MARK: - Private Methods
    
    private func scheduleAppLaunchCompletion(for activity: Activity<AppLaunchActivity>) {
        Task {
            // Display for 3 seconds with gradual progress updates
            let totalDuration: TimeInterval = 3.0
            let updateInterval: TimeInterval = 0.3
            let steps = Int(totalDuration / updateInterval)
            
            for step in 1...steps {
                guard currentActivity?.id == activity.id else { break }
                
                let progress = Double(step) / Double(steps)
                let greeting = "الله"
                var subGreeting = "بسم الله الرحمن الرحيم"
                
                // Progressive greeting messages
                if progress > 0.3 {
                    subGreeting = "Loading prayer times..."
                }
                if progress > 0.6 {
                    subGreeting = "Preparing worship experience..."
                }
                if progress > 0.9 {
                    subGreeting = "DeenBuddy Ready"
                }
                
                await updateAppLaunchProgress(
                    greeting: greeting,
                    subGreeting: subGreeting,
                    progress: progress,
                    isLoading: progress < 1.0
                )
                
                try? await Task.sleep(nanoseconds: UInt64(updateInterval * 1_000_000_000))
            }
            
            // End the activity after completion
            await endCurrentActivity()
        }
    }
}

// MARK: - App Launch Widget Views

#if canImport(WidgetKit) && !os(macOS)
@available(iOS 16.1, *)
struct AppLaunchLiveActivityView: View {
    let state: AppLaunchActivity.ContentState
    
    var body: some View {
        VStack(spacing: 12) {
            // Main Allah symbol
            Text(state.greeting)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .scaleEffect(state.isLoading ? 1.0 : 1.1)
                .animation(.easeInOut(duration: 0.5), value: state.isLoading)
            
            // Subtitle greeting
            Text(state.subGreeting)
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Progress indicator
            if state.isLoading {
                ProgressView(value: state.progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                    .frame(maxWidth: 200)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

// MARK: - Dynamic Island Views for App Launch

@available(iOS 16.1, *)
extension AppLaunchLiveActivityView {
    
    /// Compact leading view for Dynamic Island - Allah symbol
    @ViewBuilder
    func dynamicIslandCompactLeading() -> some View {
        HStack(spacing: 2) {
            Text("الله")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            if state.isLoading {
                ProgressView()
                    .scaleEffect(0.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
        }
    }

    /// Compact trailing view for Dynamic Island - progress or completion
    @ViewBuilder
    func dynamicIslandCompactTrailing() -> some View {
        if state.isLoading {
            Text("\(Int(state.progress * 100))%")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        } else {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(.green)
        }
    }

    /// Minimal view for Dynamic Island - persistent Allah symbol
    @ViewBuilder
    func dynamicIslandMinimal() -> some View {
        Text("الله")
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
    }
    
    /// Expanded view for Dynamic Island - full launch experience
    @ViewBuilder
    func dynamicIslandExpanded() -> some View {
        VStack(spacing: 8) {
            // Top row: Allah symbol and app name
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("الله")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("DeenBuddy")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    if state.isLoading {
                        ProgressView(value: state.progress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .white))
                            .frame(width: 60)
                        
                        Text("\(Int(state.progress * 100))%")
                            .font(.caption2)
                            .foregroundColor(.white)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text("Ready")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            
            // Bottom row: Islamic greeting
            HStack {
                Text(state.subGreeting)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Spacer()
            }
        }
        .padding()
    }
}
#endif
