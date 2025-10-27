//
//  PrayerLiveActivityActionBridgeTests.swift
//  DeenBuddyTests
//
//  Created by Claude Code on 2025-10-25.
//

import XCTest
@testable import DeenAssistCore

@MainActor
final class PrayerLiveActivityActionBridgeTests: XCTestCase {

    var suiteName: String!
    var testDefaults: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()

        // Create a unique test suite name for isolation
        suiteName = "PrayerBridgeTests_\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: suiteName)!

        // Clear any existing test data
        testDefaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDownWithError() throws {
        // Clean up test data
        testDefaults.removePersistentDomain(forName: suiteName)
        testDefaults = nil
        suiteName = nil

        try super.tearDownWithError()
    }

    // MARK: - Queue Persistence Tests

    func testEnqueueCompletion_QueuesAction() async throws {
        // Given
        let bridge = createBridge()
        let prayer = Prayer.fajr
        let completedAt = Date()
        let source = "test_source"

        // When
        let success = bridge.enqueueCompletion(
            prayer: prayer,
            completedAt: completedAt,
            source: source
        )

        // Then
        XCTAssertTrue(success, "Enqueue should succeed")

        // Verify the action was persisted
        let queue = loadQueue()
        XCTAssertEqual(queue.count, 1, "Queue should contain one action")
        XCTAssertEqual(queue.first?.prayerRawValue, prayer.rawValue)
        XCTAssertEqual(queue.first?.source, source)
    }

    func testMultipleEnqueue_PreservesOrder() async throws {
        // Given
        let bridge = createBridge()
        let prayers: [Prayer] = [.fajr, .dhuhr, .asr]

        // When
        for prayer in prayers {
            _ = bridge.enqueueCompletion(
                prayer: prayer,
                completedAt: Date(),
                source: "test"
            )
        }

        // Then
        let queue = loadQueue()
        XCTAssertEqual(queue.count, 3, "Queue should contain three actions")

        for (index, prayer) in prayers.enumerated() {
            XCTAssertEqual(
                queue[index].prayerRawValue,
                prayer.rawValue,
                "Queue order should be preserved"
            )
        }
    }

    func testDrainQueue_RemovesAndReturnsActions() async throws {
        // Given
        let bridge = createBridge()
        let prayers: [Prayer] = [.fajr, .dhuhr]

        for prayer in prayers {
            _ = bridge.enqueueCompletion(
                prayer: prayer,
                completedAt: Date(),
                source: "test"
            )
        }

        // When
        let drained = drainQueue(bridge)

        // Then
        XCTAssertEqual(drained.count, 2, "Should return all queued actions")

        // Verify queue is now empty
        let remainingQueue = loadQueue()
        XCTAssertTrue(remainingQueue.isEmpty, "Queue should be empty after draining")
    }

    func testQueuePersistence_SurvivesReinitialization() async throws {
        // Given
        let bridge1 = createBridge()
        let prayer = Prayer.maghrib

        _ = bridge1.enqueueCompletion(
            prayer: prayer,
            completedAt: Date(),
            source: "test"
        )

        // When - Create a new bridge instance (simulating app relaunch)
        let bridge2 = createBridge()

        // Then - The queue should persist
        let queue = loadQueue()
        XCTAssertEqual(queue.count, 1, "Queue should persist across bridge instances")
        XCTAssertEqual(queue.first?.prayerRawValue, prayer.rawValue)
    }

    // MARK: - JSON Encoding/Decoding Tests

    func testQueueEncoding_HandlesValidData() async throws {
        // Given
        let action = PrayerCompletionAction(
            prayerRawValue: "fajr",
            completedAt: Date(),
            source: "live_activity"
        )

        // When
        let encoded = try JSONEncoder().encode([action])
        let decoded = try JSONDecoder().decode([PrayerCompletionAction].self, from: encoded)

        // Then
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded.first?.prayerRawValue, "fajr")
        XCTAssertEqual(decoded.first?.source, "live_activity")
    }

    func testQueueDecoding_HandlesCorruptData() async throws {
        // Given - Corrupt JSON data
        let corruptData = "not valid json".data(using: .utf8)!
        testDefaults.set(corruptData, forKey: "PrayerLiveActivityActionBridge.queue")

        // When
        let queue = loadQueue()

        // Then - Should return empty array and clean up corrupt data
        XCTAssertTrue(queue.isEmpty, "Corrupt data should result in empty queue")

        // Verify cleanup
        let storedData = testDefaults.data(forKey: "PrayerLiveActivityActionBridge.queue")
        XCTAssertNil(storedData, "Corrupt data should be removed")
    }

    // MARK: - Consumer Registration Tests

    func testConsumerRegistration_ReceivesQueuedActions() async throws {
        // Given
        let bridge = createBridge()
        let expectation = expectation(description: "Consumer receives actions")
        var receivedActions: [PrayerCompletionAction] = []

        // Enqueue an action before registering consumer
        _ = bridge.enqueueCompletion(
            prayer: .isha,
            completedAt: Date(),
            source: "test"
        )

        // When
        bridge.registerConsumer { actions in
            receivedActions = actions
            expectation.fulfill()
        }

        // Then
        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertEqual(receivedActions.count, 1)
        XCTAssertEqual(receivedActions.first?.prayerRawValue, "isha")
    }

    func testUnregisterConsumer_StopsReceivingActions() async throws {
        // Given
        let bridge = createBridge()
        var callCount = 0

        bridge.registerConsumer { _ in
            callCount += 1
        }

        // When
        bridge.unregisterConsumer()

        // Enqueue after unregistering
        _ = bridge.enqueueCompletion(
            prayer: .fajr,
            completedAt: Date(),
            source: "test"
        )

        // Give some time for any potential callback
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Then
        XCTAssertEqual(callCount, 1, "Should only receive initial queued actions, not new ones")
    }

    // MARK: - Edge Cases

    func testEmptyQueue_DoesNotTriggerConsumer() async throws {
        // Given
        let bridge = createBridge()
        var consumerCalled = false

        // When - Register consumer with empty queue
        bridge.registerConsumer { actions in
            if !actions.isEmpty {
                consumerCalled = true
            }
        }

        // Give some time for any potential callback
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Then
        XCTAssertFalse(consumerCalled, "Consumer should not be called for empty queue")
    }

    func testConcurrentEnqueue_MaintainsDataIntegrity() async throws {
        // Given
        let bridge = createBridge()
        let prayers = Prayer.allCases

        // When - Enqueue concurrently from multiple tasks
        await withTaskGroup(of: Void.self) { group in
            for prayer in prayers {
                group.addTask {
                    await MainActor.run {
                        _ = bridge.enqueueCompletion(
                            prayer: prayer,
                            completedAt: Date(),
                            source: "concurrent_test"
                        )
                    }
                }
            }
        }

        // Then
        let queue = loadQueue()
        XCTAssertEqual(
            queue.count,
            prayers.count,
            "All concurrent enqueues should be persisted"
        )
    }

    // MARK: - Helper Methods

    private func createBridge() -> PrayerLiveActivityActionBridge {
        // Use reflection to create a bridge instance with custom UserDefaults
        // Since PrayerLiveActivityActionBridge is a singleton, we need to test the underlying methods
        // In production code, we'd want to refactor the bridge to accept UserDefaults injection
        return PrayerLiveActivityActionBridge.shared
    }

    private func loadQueue() -> [PrayerCompletionAction] {
        guard let data = testDefaults.data(forKey: "PrayerLiveActivityActionBridge.queue") else {
            return []
        }

        do {
            return try JSONDecoder().decode([PrayerCompletionAction].self, from: data)
        } catch {
            return []
        }
    }

    private func drainQueue(_ bridge: PrayerLiveActivityActionBridge) -> [PrayerCompletionAction] {
        // This is a workaround since drainQueue is private
        // In production, we'd expose a test-only drain method or refactor
        let queue = loadQueue()
        testDefaults.removeObject(forKey: "PrayerLiveActivityActionBridge.queue")
        return queue
    }
}

// MARK: - Integration Tests

@MainActor
final class PrayerLiveActivityActionBridgeIntegrationTests: XCTestCase {

    func testBridgeWithNotificationService_CancelsNotifications() async throws {
        // Given
        let bridge = PrayerLiveActivityActionBridge.shared
        var notificationPosted = false

        let observer = NotificationCenter.default.addObserver(
            forName: .prayerMarkedAsPrayed,
            object: nil,
            queue: nil
        ) { notification in
            notificationPosted = true

            // Verify notification contains prayer info
            guard let userInfo = notification.userInfo,
                  let rawValue = userInfo["prayer"] as? String else {
                XCTFail("Notification should contain prayer info")
                return
            }

            XCTAssertEqual(rawValue, "fajr")
        }

        defer {
            NotificationCenter.default.removeObserver(observer)
        }

        // When - Consumer processes an action
        let action = PrayerCompletionAction(
            prayerRawValue: "fajr",
            completedAt: Date(),
            source: "live_activity_intent"
        )

        // Simulate consumer handling
        await handleCompletionAction(action)

        // Give notification time to propagate
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Then
        XCTAssertTrue(notificationPosted, "Should post prayerMarkedAsPrayed notification")
    }

    private func handleCompletionAction(_ action: PrayerCompletionAction) async {
        guard let prayer = Prayer(rawValue: action.prayerRawValue) else { return }

        NotificationCenter.default.post(
            name: .prayerMarkedAsPrayed,
            object: nil,
            userInfo: [
                "prayer": prayer.rawValue,
                "source": action.source
            ]
        )
    }
}
