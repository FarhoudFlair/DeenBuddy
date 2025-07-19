#!/usr/bin/env swift

import Foundation
import Combine

// This script demonstrates the SettingsService rollback mechanism
// It shows how settings revert to previous values when save operations fail

print("🔧 SettingsService Rollback Mechanism Demonstration")
print(String(repeating: "=", count: 60))

// Simulate the rollback mechanism behavior
class MockSettingsService {
    // Flag to prevent infinite recursion during rollback operations
    private var isRollingBack: Bool = false

    @Published var notificationsEnabled: Bool = true {
        didSet {
            // Prevent recursion during rollback operations
            guard !isRollingBack else {
                print("🛡️ Rollback in progress, skipping didSet to prevent recursion")
                return
            }

            let oldValue = oldValue
            let newValue = notificationsEnabled

            print("📝 Setting notificationsEnabled: \(oldValue) → \(newValue)")

            // Simulate immediate UI update
            print("✅ UI immediately reflects change: \(newValue)")

            // Simulate async save with potential rollback
            simulateAsyncSave(
                propertyName: "notificationsEnabled",
                oldValue: oldValue,
                newValue: newValue,
                rollbackAction: {
                    print("🔄 Rolling back notificationsEnabled: \(newValue) → \(oldValue)")

                    // Use defer to ensure flag is reset even if an error occurs
                    defer {
                        self.isRollingBack = false
                    }

                    // Set flag to prevent recursion
                    self.isRollingBack = true

                    // Perform the rollback
                    self.notificationsEnabled = oldValue
                }
            )
        }
    }
    
    private func simulateAsyncSave(
        propertyName: String,
        oldValue: Any,
        newValue: Any,
        rollbackAction: @escaping () -> Void
    ) {
        // Simulate debounced save operation
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            // Simulate random save failure (30% chance)
            let saveSucceeds = Int.random(in: 1...10) > 3
            
            DispatchQueue.main.async {
                if saveSucceeds {
                    print("✅ Save succeeded for \(propertyName) = \(newValue)")
                    print("💾 Value persisted to UserDefaults")
                } else {
                    print("❌ Save failed for \(propertyName)")
                    print("🔄 Executing rollback action...")
                    rollbackAction()
                    print("📢 Posted .settingsSaveFailed notification with rollback info")
                    print("   - propertyName: \(propertyName)")
                    print("   - attemptedValue: \(newValue)")
                    print("   - rolledBackTo: \(oldValue)")
                    print("   - rollbackPerformed: true")
                }
            }
        }
    }
}

// Async demonstration function to avoid blocking threads
@MainActor
func runDemonstration() async {
    do {
        print("\n🎯 Scenario 1: Successful Save")
        print(String(repeating: "-", count: 30))

        let mockService = MockSettingsService()
        print("Initial value: \(mockService.notificationsEnabled)")

        // Change setting
        mockService.notificationsEnabled = false

        // Wait for async operation (non-blocking)
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        print("\n🎯 Scenario 2: Save Failure with Rollback")
        print(String(repeating: "-", count: 40))

        // Try multiple changes to demonstrate rollback
        for i in 1...3 {
            print("\n--- Attempt \(i) ---")
            mockService.notificationsEnabled = !mockService.notificationsEnabled

            // Wait for async operation (non-blocking)
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
    } catch {
        print("⚠️ Error during demonstration: \(error)")
    }
}

// Run the demonstration asynchronously and wait for completion
Task {
    await runDemonstration()

    // Print informational content after demonstration completes
    print("\n📋 Key Benefits of Rollback Mechanism:")
    print("1. ✅ UI immediately reflects user changes (good UX)")
    print("2. 🔄 Settings revert if save fails (data consistency)")
    print("3. 📢 Notifications inform UI of failures (error handling)")
    print("4. 🏷️  Detailed failure info helps debugging")
    print("5. 🔒 Prevents UI-data inconsistency issues")

    print("\n🔍 Implementation Details:")
    print("- Each @Published property has a didSet observer")
    print("- didSet captures oldValue before change")
    print("- Rollback action reverts property to oldValue")
    print("- saveSettingsAsync() executes rollback on failure")
    print("- .settingsSaveFailed notification includes rollback info")

    print("\n✨ This fixes the original issue where:")
    print("- notificationsEnabled would post .settingsDidChange immediately")
    print("- saveSettingsAsync() would fail silently")
    print("- UI state wouldn't match persisted data")
    print("- Users would see inconsistent behavior")

    print("\n🎉 Now the system ensures UI-data consistency!")
    print(String(repeating: "=", count: 60))

    // Exit the script gracefully
    exit(0)
}

// Keep the script running until async operations complete
RunLoop.main.run()
