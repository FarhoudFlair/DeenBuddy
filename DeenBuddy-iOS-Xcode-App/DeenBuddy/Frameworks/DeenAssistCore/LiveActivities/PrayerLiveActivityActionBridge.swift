import Foundation
import os

/// Represents a completion action triggered outside the main app (e.g., Live Activity or widget).
public struct PrayerCompletionAction: Codable, Sendable {
    public let prayerRawValue: String
    public let completedAt: Date
    public let source: String

    public init(prayerRawValue: String, completedAt: Date, source: String) {
        self.prayerRawValue = prayerRawValue
        self.completedAt = completedAt
        self.source = source
    }
}

/// Bridge layer for sharing prayer completion actions between the Live Activity extension and the host app.
public final class PrayerLiveActivityActionBridge {

    // MARK: - Shared Constants

    public static let appGroupIdentifier = "group.com.deenbuddy.app"
    private static let queueKey = "PrayerLiveActivityActionBridge.queue"
    private static let subsystem = "com.deenbuddy.app"
    private static let category = "PrayerLiveActivityBridge"
    private static let darwinNotificationName = "com.deenbuddy.app.prayerCompletion"
    private static let tempFilePrefix = ".tmp-"
    private static let tempFileExpirationInterval: TimeInterval = 60 * 60 // 1 hour
    private static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        return formatter
    }()

    // MARK: - Singleton

    public static let shared = PrayerLiveActivityActionBridge()

    private let userDefaults: UserDefaults?
    private let logger = Logger(subsystem: subsystem, category: category)
    private let fileCoordinator = NSFileCoordinator()
    private let fileManager = FileManager.default
    private var migrationComplete = false

#if canImport(UIKit)
    private var observerPointer: UnsafeMutableRawPointer?
    private var consumerHandler: (([PrayerCompletionAction]) async -> Void)?
#endif

    private lazy var queueDirectoryURL: URL? = {
        guard let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier) else {
            logger.error("Failed to get App Group container URL")
            return nil
        }
        return containerURL.appendingPathComponent("Library/PrayerCompletionQueue", isDirectory: true)
    }()

    private init(userDefaults: UserDefaults? = nil) {
        if let userDefaults {
            self.userDefaults = userDefaults
        } else {
            self.userDefaults = UserDefaults(suiteName: Self.appGroupIdentifier)
        }
    }

    // MARK: - Extension-facing API

    /// Enqueue a completion action originating from a Live Activity or widget.
    @discardableResult
    @MainActor
    public func enqueueCompletion(prayer: Prayer, completedAt: Date = Date(), source: String) -> Bool {
        migrateLegacyQueueIfNeeded()
        
        guard let queueDirectory = ensureQueueDirectory() else {
            logger.error("Failed to create queue directory; cannot enqueue")
            return false
        }

        let action = PrayerCompletionAction(prayerRawValue: prayer.rawValue, completedAt: completedAt, source: source)
        
        // Create unique filename: timestamp-uuid.json
        let timestamp = Self.timestampFormatter.string(from: completedAt).replacingOccurrences(of: ":", with: "-")
        let filename = "\(timestamp)-\(UUID().uuidString).json"
        let finalURL = queueDirectory.appendingPathComponent(filename)
        let tempURL = queueDirectory.appendingPathComponent(".tmp-\(UUID().uuidString)")

        // Write to temp file first
        do {
            let data = try JSONEncoder().encode(action)
            try data.write(to: tempURL, options: .atomic)
        } catch {
            logger.error("Failed to encode/write action to temp file: \(error.localizedDescription, privacy: .public)")
            return false
        }

        // Coordinate atomic move to final destination
        var coordinationError: NSError?
        var moveSucceeded = false
        fileCoordinator.coordinate(writingItemAt: finalURL, options: .forReplacing, error: &coordinationError) { destinationURL in
            do {
                try fileManager.moveItem(at: tempURL, to: destinationURL)
                moveSucceeded = true
            } catch {
                // Log move failure - don't modify coordinationError from within closure (exclusivity violation)
                logger.error("Failed to move action file: \(error.localizedDescription, privacy: .public)")
                // moveSucceeded remains false, which will trigger cleanup below
            }
        }

        // Cleanup temp file and return false if move failed
        if !moveSucceeded {
            try? fileManager.removeItem(at: tempURL)
            logger.error("Enqueue failed: move operation failed")
            return false
        }

        postDarwinNotification()
        logger.debug("Enqueued completion for \(prayer.displayName, privacy: .public) via \(source, privacy: .public)")
        return true
    }

    // MARK: - App-facing API

#if canImport(UIKit)
    /// Register a consumer that will be notified whenever new completion actions arrive.
    /// The handler is invoked on the main actor and receives any pending actions immediately.
    @MainActor
    public func registerConsumer(_ handler: @escaping ([PrayerCompletionAction]) async -> Void) {
        guard userDefaults != nil else {
            logger.error("App Group UserDefaults unavailable; cannot register consumer")
            return
        }
        consumerHandler = handler
        setupObserverIfNeeded()
        dispatchPendingActions()
    }

    /// Unregister the consumer and stop listening for Darwin notifications.
    @MainActor
    public func unregisterConsumer() {
        if let pointer = observerPointer {
            CFNotificationCenterRemoveObserver(
                CFNotificationCenterGetDarwinNotifyCenter(),
                pointer,
                CFNotificationName(Self.darwinNotificationName as CFString),
                nil
            )
            observerPointer = nil
        }
        consumerHandler = nil
    }
    
    /// Clean up observer on deallocation to prevent use-after-free
    deinit {
        // This is safe because CFNotificationCenter operations don't require MainActor
        if let pointer = observerPointer {
            CFNotificationCenterRemoveObserver(
                CFNotificationCenterGetDarwinNotifyCenter(),
                pointer,
                CFNotificationName(Self.darwinNotificationName as CFString),
                nil
            )
        }
    }
#endif

    // MARK: - Queue Management

    private func drainQueue() -> [PrayerCompletionAction] {
        migrateLegacyQueueIfNeeded()
        
        guard let queueDirectory = queueDirectoryURL,
              fileManager.fileExists(atPath: queueDirectory.path) else {
            return []
        }

        var results: [PrayerCompletionAction] = []

        // Enumerate all JSON files
        guard let files = try? fileManager.contentsOfDirectory(
            at: queueDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        for fileURL in files where fileURL.pathExtension == "json" {
            var readError: NSError?
            var decodedAction: PrayerCompletionAction?

            // Coordinate read
            fileCoordinator.coordinate(readingItemAt: fileURL, options: .withoutChanges, error: &readError) { readURL in
                do {
                    let data = try Data(contentsOf: readURL)
                    let action = try JSONDecoder().decode(PrayerCompletionAction.self, from: data)
                    decodedAction = action
                } catch {
                    // Delete corrupted file to prevent infinite retries
                    logger.error("Failed to decode action file, deleting: \(error.localizedDescription, privacy: .public)")
                    try? fileManager.removeItem(at: readURL)
                }
            }

            // If read and decode succeeded, coordinate delete
            if readError == nil, let action = decodedAction {
                var deleteError: NSError?
                var deleteSucceeded = false
                fileCoordinator.coordinate(writingItemAt: fileURL, options: .forDeleting, error: &deleteError) { deleteURL in
                    do {
                        try fileManager.removeItem(at: deleteURL)
                        deleteSucceeded = true
                    } catch {
                        // Log delete failure - don't modify deleteError from within closure (exclusivity violation)
                        logger.error("Failed to delete processed action file: \(error.localizedDescription, privacy: .public)")
                        // deleteSucceeded remains false, preventing action from being added to results
                    }
                }

                // Only add to results if deletion succeeded to prevent duplicate processing
                if deleteSucceeded {
                    results.append(action)
                } else {
                    logger.warning("Action file not processed due to delete failure, will retry on next drain")
                }
            }
        }

        return results
    }

    // MARK: - Notifications

    private func postDarwinNotification() {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterPostNotification(
            center,
            CFNotificationName(Self.darwinNotificationName as CFString),
            nil,
            nil,
            true
        )
    }

#if canImport(UIKit)
    @MainActor
    private func setupObserverIfNeeded() {
        guard observerPointer == nil else { return }

        let pointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        observerPointer = pointer

        let callback: CFNotificationCallback = { _, observer, _, _, _ in
            guard let observer else { return }
            let bridge = Unmanaged<PrayerLiveActivityActionBridge>.fromOpaque(observer).takeUnretainedValue()
            Task { @MainActor in
                bridge.dispatchPendingActions()
            }
        }

        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            pointer,
            callback,
            Self.darwinNotificationName as CFString,
            nil,
            .deliverImmediately
        )
    }

    @MainActor
    private func dispatchPendingActions() {
        guard userDefaults != nil else { return }
        guard consumerHandler != nil else { return }
        // Offload potentially heavy file I/O from drainQueue() off the main thread
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            let actions = self.drainQueue()
            guard !actions.isEmpty else { return }
            await MainActor.run {
                guard let handler = self.consumerHandler else { return }
                Task { await handler(actions) }
            }
        }
    }
#endif

    // MARK: - File Management Helpers

    /// Ensures the queue directory exists, creating it if necessary.
    private func ensureQueueDirectory() -> URL? {
        guard let queueDirectory = queueDirectoryURL else { return nil }

        if !fileManager.fileExists(atPath: queueDirectory.path) {
            do {
                try fileManager.createDirectory(at: queueDirectory, withIntermediateDirectories: true, attributes: nil)
                logger.info("Created queue directory at \(queueDirectory.path, privacy: .public)")
            } catch {
                logger.error("Failed to create queue directory: \(error.localizedDescription, privacy: .public)")
                return nil
            }
        }

        purgeStaleTempFiles(in: queueDirectory)

        return queueDirectory
    }
    
    /// Synchronous version for use in background tasks (called off main thread).
    private func ensureQueueDirectoryInBackground() -> URL? {
        guard let queueDirectory = queueDirectoryURL else { return nil }

        if !fileManager.fileExists(atPath: queueDirectory.path) {
            do {
                try fileManager.createDirectory(at: queueDirectory, withIntermediateDirectories: true, attributes: nil)
                logger.info("Created queue directory at \(queueDirectory.path, privacy: .public)")
            } catch {
                logger.error("Failed to create queue directory: \(error.localizedDescription, privacy: .public)")
                return nil
            }
        }

        purgeStaleTempFiles(in: queueDirectory)

        return queueDirectory
    }

    /// Migrates legacy UserDefaults-based queue to file-based queue (one-time operation).
    /// File I/O operations are performed on a background queue to avoid blocking the main thread.
    private func migrateLegacyQueueIfNeeded() {
        guard !migrationComplete else { return }
        migrationComplete = true

        guard let defaults = userDefaults,
              let legacyData = defaults.data(forKey: Self.queueKey) else {
            return
        }

        logger.info("Migrating legacy queue from UserDefaults to file-based queue")

        // Offload file I/O to background queue to avoid blocking MainActor
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            
            do {
                let legacyQueue = try JSONDecoder().decode([PrayerCompletionAction].self, from: legacyData)

                guard let queueDirectory = self.ensureQueueDirectoryInBackground() else {
                    self.logger.error("Failed to create queue directory during migration")
                    return
                }

                // Convert each legacy action to a file (file I/O happens off main thread)
                for action in legacyQueue {
                    let timestamp = Self.timestampFormatter.string(from: action.completedAt).replacingOccurrences(of: ":", with: "-")
                    let filename = "\(timestamp)-\(UUID().uuidString).json"
                    let fileURL = queueDirectory.appendingPathComponent(filename)

                    do {
                        let data = try JSONEncoder().encode(action)
                        try data.write(to: fileURL, options: .atomic)
                    } catch {
                        self.logger.error("Failed to migrate action to file: \(error.localizedDescription, privacy: .public)")
                    }
                }

                // Remove legacy queue from UserDefaults on main thread
                await MainActor.run {
                    defaults.removeObject(forKey: Self.queueKey)
                    self.logger.info("Successfully migrated \(legacyQueue.count) actions from UserDefaults")
                }

            } catch {
                self.logger.error("Failed to decode legacy queue during migration: \(error.localizedDescription, privacy: .public)")
                // Remove corrupted legacy queue on main thread
                await MainActor.run {
                    defaults.removeObject(forKey: Self.queueKey)
                }
            }
        }
    }

    /// Removes stale temp files that may have been left behind if the process crashed mid-write.
    private func purgeStaleTempFiles(in directory: URL) {
        let expirationDate = Date().addingTimeInterval(-Self.tempFileExpirationInterval)
        let resourceKeys: Set<URLResourceKey> = [.creationDateKey, .contentModificationDateKey, .isDirectoryKey]

        guard let fileURLs = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: Array(resourceKeys),
            options: []
        ) else {
            return
        }

        for fileURL in fileURLs {
            guard fileURL.lastPathComponent.hasPrefix(Self.tempFilePrefix) else { continue }

            do {
                let values = try fileURL.resourceValues(forKeys: resourceKeys)
                // Skip if entry is a directory or unknown type (nil). Only proceed when explicitly not a directory.
                if values.isDirectory != false { continue }

                let referenceDate = values.creationDate ?? values.contentModificationDate

                guard let referenceDate, referenceDate < expirationDate else { continue }

                try fileManager.removeItem(at: fileURL)
                logger.debug("Removed stale temp queue file: \(fileURL.lastPathComponent, privacy: .public)")
            } catch {
                logger.debug("Skipping temp file cleanup for \(fileURL.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
