import Foundation
import Combine
import Compression
import CryptoKit
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Actor to handle thread-safe initialization
private actor InitializationActor {
    private var isInitializing = false
    
    func checkAndSetInitializing() -> Bool {
        if isInitializing {
            return false // Already initializing
        }
        isInitializing = true
        return true // Can proceed with initialization
    }
    
    func resetInitializing() {
        isInitializing = false
    }
}

// MARK: - Quran Data Cache Manager

/// Manages Quran data caching with compression and migration support
final class QuranDataCacheManager {
    static let shared = QuranDataCacheManager()

    /// UserDefaults key for cross-process migration signaling (App Group shared with Widget Extension)
    /// Note: UserDefaults flags provide inter-process coordination; NSLock provides intra-process thread safety
    static let migrationFlagKey = "com.deenbuddy.quran.migrating"

    /// UserDefaults key for cross-process cache write signaling
    static let cacheWriteInProgressKey = "com.deenbuddy.quran.cache.writing"

    private let appGroupIdentifier = "group.com.deenbuddy.app"
    private let userDefaults: UserDefaults
    private let fileQueue = DispatchQueue(label: "com.deenbuddy.quran.fileIO", qos: .utility, attributes: .concurrent)
    
    /// Intra-process synchronization for migration operations
    private let migrationLock = NSLock()
    /// Intra-process synchronization for cache write operations
    private let cacheWriteLock = NSLock()

    private enum MetadataKeys {
        static let quranCacheMetadata = "QuranCacheMetadata"
        static let migrationMetadata = "QuranCacheMigrationMetadata"
        static let lastDataUpdate = "LastDataUpdate"
        static let legacyCachedQuranData = "CachedQuranData"
    }

    private struct QuranCacheMetadata: Codable {
        static let currentVersion = 1

        let version: Int
        let timestamp: Date
        let checksum: String
        let verseCount: Int
        let fileSize: Int
        let isCompressed: Bool
        let uncompressedSize: Int?
    }

    private enum MigrationState: String, Codable {
        case notStarted
        case inProgress
        case completed
        case failed
    }

    private struct MigrationMetadata: Codable {
        let state: MigrationState
        let startedAt: Date?
        let completedAt: Date?
        let attemptCount: Int
    }

    private init() {
        if let suiteDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            userDefaults = suiteDefaults
        } else {
            print("⚠️ Falling back to standard UserDefaults – app group unavailable")
            userDefaults = .standard
        }
    }

    var lastUpdateTimestamp: Date? {
        userDefaults.object(forKey: MetadataKeys.lastDataUpdate) as? Date
    }

    static func isMigrationInProgress() -> Bool {
        QuranDataCacheManager.shared.userDefaults.bool(forKey: migrationFlagKey)
    }

    static func isCacheWriteInProgress() -> Bool {
        QuranDataCacheManager.shared.userDefaults.bool(forKey: cacheWriteInProgressKey)
    }

    func migrateLegacyCacheIfNeeded() {
        // Acquire lock to prevent concurrent migration attempts within the same process
        migrationLock.lock()
        defer { migrationLock.unlock() }
        
        var metadata = loadMigrationMetadata()

        switch metadata.state {
        case .completed:
            return
        case .inProgress:
            if let started = metadata.startedAt,
               Date().timeIntervalSince(started) < 300 {
                return
            }
            print("⚠️ Quran cache migration was stale, retrying…")
        case .failed, .notStarted:
            break
        }

        if metadata.attemptCount >= 3 {
            print("❌ Quran cache migration attempt limit reached. Clearing legacy cache.")
            userDefaults.removeObject(forKey: MetadataKeys.legacyCachedQuranData)
            saveMigrationState(.failed)
            return
        }

        guard let legacyData = userDefaults.data(forKey: MetadataKeys.legacyCachedQuranData) else {
            saveMigrationState(.completed)
            return
        }

        print("📦 Found legacy Quran cache (\(legacyData.count) bytes) – migrating.")

        metadata = MigrationMetadata(
            state: .inProgress,
            startedAt: Date(),
            completedAt: nil,
            attemptCount: metadata.attemptCount + 1
        )
        saveMigrationMetadata(metadata)
        // Set UserDefaults flag for cross-process visibility (Widget Extension, BackgroundTaskManager)
        userDefaults.set(true, forKey: Self.migrationFlagKey)

        defer {
            userDefaults.set(false, forKey: Self.migrationFlagKey)
        }

        do {
            let verses = try JSONDecoder().decode([QuranVerse].self, from: legacyData)
            try cacheVersesToFile(verses)
            guard let loadedVerses = try loadVersesFromFile() else {
                throw QuranSearchError.cachingFailed("Verification failed: cache missing after migration")
            }

            guard loadedVerses.count == verses.count else {
                throw QuranSearchError.cachingFailed("Verse count mismatch during migration")
            }

            userDefaults.removeObject(forKey: MetadataKeys.legacyCachedQuranData)
            saveMigrationState(.completed, startedAt: metadata.startedAt)
            print("✅ Quran cache migration complete (\(verses.count) verses)")
        } catch {
            deleteCacheFile()
            saveMigrationState(.failed, startedAt: metadata.startedAt)
            print("❌ Quran cache migration failed: \(error)")
        }
    }

    func saveVerses(_ verses: [QuranVerse]) throws {
        // Acquire lock to prevent concurrent cache writes within the same process
        cacheWriteLock.lock()
        defer { cacheWriteLock.unlock() }
        
        // Set UserDefaults flag for cross-process visibility (Widget Extension, BackgroundTaskManager)
        userDefaults.set(true, forKey: Self.cacheWriteInProgressKey)
        defer { userDefaults.set(false, forKey: Self.cacheWriteInProgressKey) }

        try cacheVersesToFile(verses)
        userDefaults.set(Date(), forKey: MetadataKeys.lastDataUpdate)
#if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
#endif
    }

    func loadVerses() throws -> [QuranVerse]? {
        return try loadVersesFromFile()
    }

    func clearCache() {
        deleteCacheFile()
        userDefaults.removeObject(forKey: MetadataKeys.quranCacheMetadata)
        userDefaults.removeObject(forKey: MetadataKeys.lastDataUpdate)
    }

    // MARK: - Private Helpers

    private func cacheDirectoryURL() throws -> URL {
        if let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) {
            return containerURL.appendingPathComponent("Quran", isDirectory: true)
        }

        let fallbackURL = fallbackCacheDirectoryURL()
        print("⚠️ App Group container '\(appGroupIdentifier)' unavailable; falling back to \(fallbackURL.path)")
        throw QuranSearchError.appGroupUnavailable(identifier: appGroupIdentifier, fallbackURL: fallbackURL)
    }

    private func cacheFileURL(for directoryURL: URL) -> URL {
        directoryURL.appendingPathComponent("quran-data.json.gz")
    }

    private func fallbackCacheDirectoryURL() -> URL {
        if let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            return caches.appendingPathComponent("QuranFallback", isDirectory: true)
        }

        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            return appSupport.appendingPathComponent("QuranFallback", isDirectory: true)
        }

        return FileManager.default.temporaryDirectory.appendingPathComponent("QuranFallback", isDirectory: true)
    }

    private func ensureCacheDirectoryExists(at directoryURL: URL) throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: directoryURL.path) {
            try fm.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            try fm.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: directoryURL.path
            )
        }
    }

    private func hasAvailableDiskSpace(bytes: Int) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
              let freeSpace = attributes[.systemFreeSize] as? Int64 else {
            print("⚠️ Could not determine free disk space; assuming enough.")
            return true
        }

        let required = Int64(bytes) * 2
        if freeSpace < required {
            print("❌ Not enough disk space. Free: \(freeSpace) Required: \(required)")
            return false
        }
        return true
    }

    private func writeCacheFile(_ data: Data) throws {
        try fileQueue.sync(flags: .barrier) {
            let directoryURL: URL
            do {
                directoryURL = try cacheDirectoryURL()
            } catch let QuranSearchError.appGroupUnavailable(_, fallbackURL) {
                directoryURL = fallbackURL
            } catch {
                throw error
            }

            try ensureCacheDirectoryExists(at: directoryURL)
            let fileURL = cacheFileURL(for: directoryURL)
            try data.write(to: fileURL, options: [.atomic])
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: fileURL.path
            )
            var url = fileURL
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try url.setResourceValues(values)
            print("✅ Quran cache file written (\(data.count) bytes)")
        }
    }

    private func readCacheData() -> Data? {
        fileQueue.sync {
            let directoryURL: URL
            do {
                directoryURL = try cacheDirectoryURL()
            } catch let QuranSearchError.appGroupUnavailable(_, fallbackURL) {
                directoryURL = fallbackURL
            } catch {
                print("❌ Failed to resolve cache directory while reading: \(error)")
                return nil
            }

            let fileURL = cacheFileURL(for: directoryURL)
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
            return try? Data(contentsOf: fileURL)
        }
    }

    private func deleteCacheFile() {
        fileQueue.sync(flags: .barrier) {
            let directoryURL: URL
            do {
                directoryURL = try cacheDirectoryURL()
            } catch let QuranSearchError.appGroupUnavailable(_, fallbackURL) {
                directoryURL = fallbackURL
            } catch {
                print("❌ Failed to resolve cache directory for deletion: \(error)")
                return
            }

            let fileURL = cacheFileURL(for: directoryURL)
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    private func compress(_ data: Data) -> Data? {
        data.withUnsafeBytes { sourceBuffer -> Data? in
            guard let sourcePointer = sourceBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return nil
            }

            let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)
            defer { destinationBuffer.deallocate() }

            let compressedSize = compression_encode_buffer(
                destinationBuffer,
                data.count,
                sourcePointer,
                data.count,
                nil,
                COMPRESSION_ZLIB
            )

            guard compressedSize > 0 && compressedSize < data.count else { return nil }
            return Data(bytes: destinationBuffer, count: compressedSize)
        }
    }

    private func decompress(_ data: Data, expectedSize: Int?) -> Data? {
        let destinationCapacity = expectedSize ?? data.count * 10
        return data.withUnsafeBytes { sourceBuffer -> Data? in
            guard let sourcePointer = sourceBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return nil
            }

            guard destinationCapacity > 0 else {
                return nil
            }

            let destinationBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: destinationCapacity)
            defer { destinationBuffer.deallocate() }

            let decompressedSize = compression_decode_buffer(
                destinationBuffer,
                destinationCapacity,
                sourcePointer,
                data.count,
                nil,
                COMPRESSION_ZLIB
            )

            guard decompressedSize > 0 else { return nil }
            return Data(bytes: destinationBuffer, count: decompressedSize)
        }
    }

    private func checksum(for data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private func cacheVersesToFile(_ verses: [QuranVerse]) throws {
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(verses)

        guard hasAvailableDiskSpace(bytes: jsonData.count) else {
            throw QuranSearchError.cachingFailed("Insufficient disk space")
        }

        let compressedData: Data
        if let compressed = compress(jsonData) {
            compressedData = compressed
            let ratio = Double(compressed.count) / Double(jsonData.count)
            let percentage = ratio * 100
            print(String(format: "📦 Quran cache compression: %.1f%% of original (%d → %d bytes)", percentage, jsonData.count, compressed.count))
        } else {
            compressedData = jsonData
            print("📦 Quran cache compression skipped (no benefit)")
        }
        try writeCacheFile(compressedData)

        let metadata = QuranCacheMetadata(
            version: QuranCacheMetadata.currentVersion,
            timestamp: Date(),
            checksum: checksum(for: compressedData),
            verseCount: verses.count,
            fileSize: compressedData.count,
            isCompressed: compressedData.count != jsonData.count,
            uncompressedSize: jsonData.count
        )
        saveMetadata(metadata)
    }

    private func loadVersesFromFile() throws -> [QuranVerse]? {
        guard let metadata = loadMetadata() else { return nil }

        guard metadata.version == QuranCacheMetadata.currentVersion else {
            deleteCacheFile()
            userDefaults.removeObject(forKey: MetadataKeys.quranCacheMetadata)
            throw QuranSearchError.cachingFailed("Cache version mismatch")
        }

        guard let storedData = readCacheData() else { return nil }

        let actualChecksum = checksum(for: storedData)
        guard actualChecksum == metadata.checksum else {
            deleteCacheFile()
            userDefaults.removeObject(forKey: MetadataKeys.quranCacheMetadata)
            throw QuranSearchError.cachingFailed("Cache checksum validation failed")
        }

        let decoder = JSONDecoder()
        let payload: Data
        if metadata.isCompressed, let decompressed = decompress(storedData, expectedSize: metadata.uncompressedSize) {
            payload = decompressed
        } else {
            payload = storedData
        }

        let verses = try decoder.decode([QuranVerse].self, from: payload)
        guard verses.count == metadata.verseCount else {
            throw QuranSearchError.cachingFailed("Verse count mismatch")
        }

        return verses
    }

    private func saveMetadata(_ metadata: QuranCacheMetadata) {
        if let data = try? JSONEncoder().encode(metadata) {
            userDefaults.set(data, forKey: MetadataKeys.quranCacheMetadata)
        }
    }

    private func loadMetadata() -> QuranCacheMetadata? {
        guard let data = userDefaults.data(forKey: MetadataKeys.quranCacheMetadata) else {
            return nil
        }
        return try? JSONDecoder().decode(QuranCacheMetadata.self, from: data)
    }

    private func loadMigrationMetadata() -> MigrationMetadata {
        guard let data = userDefaults.data(forKey: MetadataKeys.migrationMetadata),
              let metadata = try? JSONDecoder().decode(MigrationMetadata.self, from: data) else {
            return MigrationMetadata(state: .notStarted, startedAt: nil, completedAt: nil, attemptCount: 0)
        }
        return metadata
    }

    private func saveMigrationMetadata(_ metadata: MigrationMetadata) {
        if let data = try? JSONEncoder().encode(metadata) {
            userDefaults.set(data, forKey: MetadataKeys.migrationMetadata)
        }
    }

    private func saveMigrationState(_ state: MigrationState, startedAt: Date? = nil) {
        var metadata = loadMigrationMetadata()
        let effectiveStartedAt: Date?
        if state == .inProgress {
            effectiveStartedAt = startedAt ?? Date()
        } else if let provided = startedAt {
            effectiveStartedAt = provided
        } else {
            effectiveStartedAt = metadata.startedAt
        }

        let updated = MigrationMetadata(
            state: state,
            startedAt: effectiveStartedAt,
            completedAt: state == .completed ? Date() : metadata.completedAt,
            attemptCount: metadata.attemptCount
        )
        saveMigrationMetadata(updated)
    }
}

/// Custom errors for QuranSearchService
public enum QuranSearchError: LocalizedError {
    case duplicateKey(String)
    case initializationFailed(String)
    case dataValidationFailed(String)
    case cachingFailed(String)
    case appGroupUnavailable(identifier: String, fallbackURL: URL)
    
    public var errorDescription: String? {
        switch self {
        case .duplicateKey(let key):
            return "Duplicate key detected in famous verses: '\(key)'"
        case .initializationFailed(let reason):
            return "QuranSearchService initialization failed: \(reason)"
        case .dataValidationFailed(let reason):
            return "Quran data validation failed: \(reason)"
        case .cachingFailed(let reason):
            return "Failed to cache Quran data: \(reason)"
        case .appGroupUnavailable(let identifier, let fallbackURL):
            return "App Group \(identifier) unavailable. Using fallback directory: \(fallbackURL.path)"
        }
    }
}

/// Comprehensive Quran search service with advanced search capabilities
public class QuranSearchService: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = QuranSearchService()

    // MARK: - Published Properties

    @Published public var searchResults: [QuranSearchResult] = []
    @Published public var enhancedSearchResults: [EnhancedSearchResult] = []
    @Published public var isLoading = false
    @Published public var isBackgroundLoading = false
    @Published public var error: Error?
    @Published public var lastQuery = ""
    @Published public var searchHistory: [String] = []
    @Published public var bookmarkedVerses: [QuranVerse] = []
    @Published public var searchSuggestions: [String] = []
    @Published public var queryExpansion: QueryExpansion?
    @Published public var dataValidationResult: QuranDataValidator.ValidationResult?
    @Published public var isDataLoaded = false
    @Published public var loadingProgress: Double = 0.0

    // MARK: - Private Properties

    private var allVerses: [QuranVerse] = []
    private var allSurahs: [QuranSurah] = []
    private let userDefaults = UserDefaults.standard
    private let maxHistoryItems = 20
    private let semanticEngine = SemanticSearchEngine.shared
    private let quranAPIService = QuranAPIService()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Thread Safety
    private var isInitializing = false
    private let initializationActor = InitializationActor()
    private let cacheManager = QuranDataCacheManager.shared
    private var hasAttemptedLegacyMigration = false
    
    // MARK: - Search Cancellation
    private var currentSearchTask: Task<Void, Error>?

    // MARK: - Background Prefetch

    /// Start background prefetch of Quran data (idempotent).
    @MainActor
    public func startBackgroundPrefetch() {
        guard !isDataLoaded && !isBackgroundLoading else {
            print("🔧 DEBUG: Prefetch skipped - data already loaded or loading")
            return
        }

        print("📥 Starting background Quran prefetch...")
        loadCompleteQuranData()
    }

    // MARK: - Cache Keys

    private enum CacheKeys {
        static let searchHistory = "QuranSearchHistory"
        static let bookmarkedVerses = "BookmarkedQuranVerses"
    }

    // MARK: - Initialization

    private init() {
        loadSearchHistory()
        loadBookmarkedVerses()
        // Data loading will be triggered lazily when needed
    }

    // MARK: - Complete Quran Data Loading

    /// Ensure data is loaded before performing operations
    private func ensureDataLoaded() {
        guard !isDataLoaded && !isInitializing else { return }
        loadCompleteQuranData()
    }

    /// Ensure data is fully available before running a search query
    private func ensureDataAvailability(timeout: TimeInterval = 30) async throws {
        ensureDataLoaded()

        let start = Date()

        while true {
            let snapshot = await MainActor.run { () -> (loaded: Bool, verseCount: Int) in
                return (self.isDataLoaded, self.allVerses.count)
            }

            if snapshot.loaded && snapshot.verseCount > 0 {
                return
            }

            if Date().timeIntervalSince(start) > timeout {
                throw QuranSearchError.initializationFailed("Timed out while loading Quran data. Please check your connection and try again.")
            }

            try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        }
    }

    /// Load complete Quran data from API or cache with thread safety
    private func loadCompleteQuranData() {
        if !hasAttemptedLegacyMigration {
            cacheManager.migrateLegacyCacheIfNeeded()
            hasAttemptedLegacyMigration = true
        }
        Task.detached { [weak self] in
            guard let self = self else { return }
            
            // Use actor for thread-safe initialization check
            let canInitialize = await self.initializationActor.checkAndSetInitializing()
            guard canInitialize else {
                print("🔧 DEBUG: Data loading already in progress, skipping duplicate initialization")
                return
            }

            // Ensure initialization is always reset
            defer {
                Task {
                    await self.initializationActor.resetInitializing()
                }
            }

            print("🔧 DEBUG: Starting loadCompleteQuranData() on background thread")

            // Update UI state on main thread
            await MainActor.run {
                self.isBackgroundLoading = true
                self.loadingProgress = 0.0
            }

            // First try to load from cache (on background thread)
            if let cachedData = self.loadCachedQuranData() {
                print("📚 Loading Quran data from cache...")
                print("🔧 DEBUG: Cached data contains \(cachedData.count) verses")
                
                // Process data on background thread
                let surahs = self.createSurahsFromVerses(cachedData)
                let validation = QuranDataValidator.validateQuranData(cachedData)

                // Only proceed with cache if validation passes to avoid UI state flickering
                if validation.isValid {
                    // Update UI on main thread - data is valid, safe to mark as loaded
                    await MainActor.run {
                        self.allVerses = cachedData
                        self.allSurahs = surahs
                        self.dataValidationResult = validation
                        self.loadingProgress = 0.0
                    }

                    // Animate progress to provide feedback even with instant cache loads
                    await self.animateCacheRestoreProgress()

                    await MainActor.run {
                        self.isDataLoaded = true
                        self.loadingProgress = 1.0
                        self.isBackgroundLoading = false
                    }
                    print("✅ Cached Quran data validation passed")
                    print("🔧 DEBUG: Cache validation successful, allVerses.count = \(cachedData.count)")
                    return
                } else {
                    // Validation failed - store result for UI feedback but don't set isDataLoaded
                    await MainActor.run {
                        self.dataValidationResult = validation
                        self.isBackgroundLoading = true
                    }
                    print("⚠️ Cached data validation failed, fetching fresh data...")
                    print("🔧 DEBUG: Cache validation failed - \(validation.summary)")
                }
            } else {
                print("🔧 DEBUG: No cached data found, will fetch from API")
            }

            // Fetch fresh data from API
            await self.fetchCompleteQuranFromAPI()
        }
    }

    /// Fetch complete Quran data from external API
    private func fetchCompleteQuranFromAPI() async {
        print("🌐 Fetching complete Quran data from Al-Quran Cloud API...")
        
        await MainActor.run {
            self.loadingProgress = 0.1
        }

        do {
            // Use async/await with withCheckedThrowingContinuation for Combine publisher
            let verses = try await withCheckedThrowingContinuation { continuation in
                quranAPIService.fetchCompleteQuranCombined()
                    .retry(3)
                    .sink(
                        receiveCompletion: { completion in
                            switch completion {
                            case .finished:
                                break
                            case .failure(let error):
                                continuation.resume(throwing: error)
                            }
                        },
                        receiveValue: { verses in
                            continuation.resume(returning: verses)
                        }
                    )
                    .store(in: &self.cancellables)
            }
            
            await MainActor.run {
                self.loadingProgress = 0.8
            }
            
            print("🔧 DEBUG: Received \(verses.count) verses from API")

            // Validate the received data on background thread
            let validation = QuranDataValidator.validateQuranData(verses)
            print(validation.summary)

            if validation.isValid {
                // Process data on background thread
                let surahs = self.createSurahsFromVerses(verses)
                
                // Cache the data for future use
                self.cacheQuranData(verses)

                // Update UI on main thread
                await MainActor.run {
                    self.allVerses = verses
                    self.allSurahs = surahs
                    self.isDataLoaded = true
                    self.dataValidationResult = validation
                    self.isBackgroundLoading = false
                    self.loadingProgress = 1.0
                }

                print("🎉 Complete Quran data loaded successfully!")
                print("📊 Total verses: \(verses.count)")
                print("📊 Total surahs: \(Set(verses.map { $0.surahNumber }).count)")
            } else {
                print("⚠️ Data validation failed, using fallback data")
                await self.loadFallbackSampleData()
            }
        } catch {
            print("❌ Failed to load Quran data after retries: \(error)")
            
            await MainActor.run {
                self.error = error
                self.isBackgroundLoading = false
                self.loadingProgress = 0.0
            }
            
            // Fallback to sample data if API fails
            await self.loadFallbackSampleData()
        }
    }

    // MARK: - Data Caching

    /// Cache Quran data locally for offline use
    private func cacheQuranData(_ verses: [QuranVerse]) {
        do {
            try cacheManager.saveVerses(verses)
            print("💾 Quran data cached successfully")
        } catch {
            let cachingError = QuranSearchError.cachingFailed(error.localizedDescription)
            print("❌ \(cachingError.localizedDescription)")
            self.error = cachingError
        }
    }

    /// Returns the timestamp of the most recent successful dataset update
    public func getLastUpdateTimestamp() -> Date? {
        cacheManager.lastUpdateTimestamp
    }

    /// Load cached Quran data
    private func loadCachedQuranData() -> [QuranVerse]? {
        do {
            if let verses = try cacheManager.loadVerses() {
                print("✅ Successfully loaded \(verses.count) verses from cache")
                return verses
            }
        } catch {
            let cachingError = QuranSearchError.cachingFailed(error.localizedDescription)
            print("❌ \(cachingError.localizedDescription)")
            self.error = cachingError
        }
        return nil
    }

    /// Animate cache restore progress to give users visual feedback
    private func animateCacheRestoreProgress() async {
        let steps = 10
        let delay: UInt64 = 50_000_000 // 0.05s
        for step in 1...steps {
            try? await Task.sleep(nanoseconds: delay)
            await MainActor.run {
                self.loadingProgress = Double(step) / Double(steps)
            }
        }
    }

    /// Create surah objects from verses with thread-safe dictionary creation
    private func createSurahsFromVerses(_ verses: [QuranVerse]) -> [QuranSurah] {
        // Use thread-safe grouping to prevent race conditions
        var groupedVerses: [Int: [QuranVerse]] = [:]
        
        for verse in verses {
            if groupedVerses[verse.surahNumber] == nil {
                groupedVerses[verse.surahNumber] = []
            }
            groupedVerses[verse.surahNumber]?.append(verse)
        }
        
        return groupedVerses.compactMap { surahNumber, surahVerses in
            guard let firstVerse = surahVerses.first else { return nil }

            return QuranSurah(
                number: surahNumber,
                name: firstVerse.surahName,
                nameArabic: firstVerse.surahNameArabic,
                nameTransliteration: firstVerse.surahName, // Use name as transliteration fallback
                meaning: firstVerse.surahName, // Use name as meaning fallback
                verseCount: surahVerses.count,
                revelationPlace: firstVerse.revelationPlace,
                revelationOrder: surahNumber, // Use surah number as revelation order fallback
                verses: surahVerses
            )
        }.sorted { $0.number < $1.number }
    }

    /// Fallback to sample data if API fails
    private func loadFallbackSampleData() async {
        print("⚠️ Loading fallback sample data...")
        print("🔧 DEBUG: Creating sample verses...")
        
        // Create sample data on background thread
        let sampleVerses = createSampleVerses()
        let sampleSurahs = createSampleSurahs()
        let validation = QuranDataValidator.validateQuranData(sampleVerses)

        print("🔧 DEBUG: Sample data created - \(sampleVerses.count) verses, \(sampleSurahs.count) surahs")
        print("📊 Sample data validation: \(validation.isValid ? "✅ PASSED" : "❌ FAILED")")
        
        // Log some sample verses for debugging
        for (index, verse) in sampleVerses.prefix(3).enumerated() {
            print("🔧 DEBUG: Sample verse \(index + 1): \(verse.shortReference) - \(verse.textTranslation.prefix(50))...")
        }

        // Update UI on main thread
        await MainActor.run {
            self.allVerses = sampleVerses
            self.allSurahs = sampleSurahs
            self.isDataLoaded = true
            self.dataValidationResult = validation
            self.isBackgroundLoading = false
            self.loadingProgress = 1.0
        }
    }

    private func createSampleVerses() -> [QuranVerse] {
        return [
            // Al-Fatiha (Chapter 1)
            QuranVerse(
                surahNumber: 1, surahName: "Al-Fatiha", surahNameArabic: "الفاتحة",
                verseNumber: 1, textArabic: "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ",
                textTranslation: "In the name of Allah, the Entirely Merciful, the Especially Merciful.",
                textTransliteration: "Bismillahi r-rahmani r-raheem",
                revelationPlace: .mecca, juzNumber: 1, hizbNumber: 1, rukuNumber: 1, manzilNumber: 1, pageNumber: 1,
                themes: ["mercy", "compassion", "beginning", "prayer", "Allah", "divine names", "bismillah", "opening", "blessing", "invocation", "worship", "devotion", "kindness", "grace", "love"],
                keywords: ["Allah", "Rahman", "Raheem", "mercy", "compassion", "name", "bismillah", "merciful", "gracious", "benevolent", "kind", "loving", "forgiving", "gentle", "tender"]
            ),
            QuranVerse(
                surahNumber: 1, surahName: "Al-Fatiha", surahNameArabic: "الفاتحة",
                verseNumber: 2, textArabic: "الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ",
                textTranslation: "All praise is due to Allah, Lord of the worlds.",
                textTransliteration: "Alhamdu lillahi rabbi l-alameen",
                revelationPlace: .mecca, juzNumber: 1, hizbNumber: 1, rukuNumber: 1, manzilNumber: 1, pageNumber: 1,
                themes: ["praise", "gratitude", "lordship", "creation", "worlds", "thankfulness", "worship", "acknowledgment", "sovereignty", "universe", "dominion", "authority", "reverence", "submission"],
                keywords: ["praise", "Allah", "Lord", "worlds", "creation", "gratitude", "hamd", "rabb", "alameen", "universe", "thankful", "grateful", "worship", "adoration", "reverence", "master", "sustainer", "cherisher", "provider"]
            ),

            // Al-Baqarah (Chapter 2) - Famous verses
            QuranVerse(
                surahNumber: 2, surahName: "Al-Baqarah", surahNameArabic: "البقرة",
                verseNumber: 255, textArabic: "اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ",
                textTranslation: "Allah - there is no deity except Him, the Ever-Living, the Sustainer of existence.",
                textTransliteration: "Allahu la ilaha illa huwa l-hayyu l-qayyoom",
                revelationPlace: .medina, juzNumber: 3, hizbNumber: 5, rukuNumber: 35, manzilNumber: 1, pageNumber: 42,
                themes: ["monotheism", "Allah", "life", "sustenance", "throne", "protection", "unity", "oneness", "divine attributes", "eternity", "permanence", "power", "sovereignty", "knowledge", "guardian", "watchful", "omniscience", "omnipotence", "tawhid", "kursi"],
                keywords: ["Allah", "deity", "living", "sustainer", "throne", "Ayat al-Kursi", "hayy", "qayyoom", "monotheism", "unity", "oneness", "eternal", "everlasting", "self-sustaining", "guardian", "protector", "knowledge", "power", "sovereignty", "kursi", "encompassing", "watchful", "omniscient", "omnipotent", "divine", "sacred", "holy", "tawhid", "la ilaha illa Allah"]
            ),
            QuranVerse(
                surahNumber: 2, surahName: "Al-Baqarah", surahNameArabic: "البقرة",
                verseNumber: 286, textArabic: "لَا يُكَلِّفُ اللَّهُ نَفْسًا إِلَّا وُسْعَهَا",
                textTranslation: "Allah does not charge a soul except with that within its capacity.",
                textTransliteration: "La yukallifu llahu nafsan illa wus'aha",
                revelationPlace: .medina, juzNumber: 3, hizbNumber: 6, rukuNumber: 40, manzilNumber: 1, pageNumber: 49,
                themes: ["mercy", "capacity", "burden", "justice", "forgiveness"],
                keywords: ["Allah", "soul", "capacity", "burden", "mercy", "justice"]
            ),

            // Al-Ikhlas (Chapter 112) - Complete chapter
            QuranVerse(
                surahNumber: 112, surahName: "Al-Ikhlas", surahNameArabic: "الإخلاص",
                verseNumber: 1, textArabic: "قُلْ هُوَ اللَّهُ أَحَدٌ",
                textTranslation: "Say, He is Allah, the One!",
                textTransliteration: "Qul huwa llahu ahad",
                revelationPlace: .mecca, juzNumber: 30, hizbNumber: 60, rukuNumber: 1, manzilNumber: 7, pageNumber: 604,
                themes: ["monotheism", "unity", "oneness", "Allah"],
                keywords: ["Allah", "one", "unity", "monotheism", "say"]
            ),
            QuranVerse(
                surahNumber: 112, surahName: "Al-Ikhlas", surahNameArabic: "الإخلاص",
                verseNumber: 2, textArabic: "اللَّهُ الصَّمَدُ",
                textTranslation: "Allah, the Eternal Refuge.",
                textTransliteration: "Allahu s-samad",
                revelationPlace: .mecca, juzNumber: 30, hizbNumber: 60, rukuNumber: 1, manzilNumber: 7, pageNumber: 604,
                themes: ["eternity", "refuge", "independence", "Allah"],
                keywords: ["Allah", "eternal", "refuge", "samad", "independent"]
            ),

            // More verses for comprehensive search testing
            QuranVerse(
                surahNumber: 3, surahName: "Ali 'Imran", surahNameArabic: "آل عمران",
                verseNumber: 185, textArabic: "كُلُّ نَفْسٍ ذَائِقَةُ الْمَوْتِ",
                textTranslation: "Every soul will taste death.",
                textTransliteration: "Kullu nafsin dha'iqatu l-mawt",
                revelationPlace: .medina, juzNumber: 4, hizbNumber: 8, rukuNumber: 19, manzilNumber: 2, pageNumber: 75,
                themes: ["death", "mortality", "soul", "certainty", "afterlife"],
                keywords: ["soul", "death", "taste", "mortality", "certainty"]
            ),
            QuranVerse(
                surahNumber: 24, surahName: "An-Nur", surahNameArabic: "النور",
                verseNumber: 35, textArabic: "اللَّهُ نُورُ السَّمَاوَاتِ وَالْأَرْضِ",
                textTranslation: "Allah is the light of the heavens and the earth.",
                textTransliteration: "Allahu nuru s-samawati wa l-ard",
                revelationPlace: .medina, juzNumber: 18, hizbNumber: 36, rukuNumber: 5, manzilNumber: 4, pageNumber: 353,
                themes: ["light", "guidance", "heavens", "earth", "divine", "illumination"],
                keywords: ["Allah", "light", "heavens", "earth", "guidance", "divine"]
            ),
            QuranVerse(
                surahNumber: 55, surahName: "Ar-Rahman", surahNameArabic: "الرحمن",
                verseNumber: 13, textArabic: "فَبِأَيِّ آلَاءِ رَبِّكُمَا تُكَذِّبَانِ",
                textTranslation: "So which of the favors of your Lord would you deny?",
                textTransliteration: "Fabi-ayyi ala'i rabbikuma tukadhdhibaan",
                revelationPlace: .mecca, juzNumber: 27, hizbNumber: 53, rukuNumber: 2, manzilNumber: 6, pageNumber: 531,
                themes: ["blessings", "gratitude", "favors", "Lord", "denial"],
                keywords: ["favors", "Lord", "deny", "blessings", "gratitude"]
            ),
            
            // Add more comprehensive sample data for testing
            QuranVerse(
                surahNumber: 2, surahName: "Al-Baqarah", surahNameArabic: "البقرة",
                verseNumber: 155, textArabic: "وَلَنَبْلُوَنَّكُم بِشَيْءٍ مِّنَ الْخَوْفِ وَالْجُوعِ",
                textTranslation: "And We will surely test you with something of fear and hunger and a loss of wealth and lives and fruits, but give good tidings to the patient.",
                textTransliteration: "Wa la nablu wannakum bi shay'in minal khawfi wal ju'i",
                revelationPlace: .medina, juzNumber: 2, hizbNumber: 3, rukuNumber: 19, manzilNumber: 1, pageNumber: 24,
                themes: ["test", "trial", "patience", "fear", "hunger", "loss", "good tidings"],
                keywords: ["test", "fear", "hunger", "patient", "trial", "loss", "wealth"]
            ),
            QuranVerse(
                surahNumber: 4, surahName: "An-Nisa", surahNameArabic: "النساء", 
                verseNumber: 29, textArabic: "يَا أَيُّهَا الَّذِينَ آمَنُوا لَا تَأْكُلُوا أَمْوَالَكُم",
                textTranslation: "O you who believe! Do not consume one another's wealth unjustly but only [in lawful] business by mutual consent.",
                textTransliteration: "Ya ayyuha alladheena amanoo la ta'kuloo amwalakum",
                revelationPlace: .medina, juzNumber: 5, hizbNumber: 9, rukuNumber: 4, manzilNumber: 2, pageNumber: 83,
                themes: ["wealth", "justice", "business", "consent", "believers", "lawful"],
                keywords: ["believe", "wealth", "consume", "unjustly", "business", "consent"]
            ),
            QuranVerse(
                surahNumber: 5, surahName: "Al-Ma'idah", surahNameArabic: "المائدة",
                verseNumber: 3, textArabic: "حُرِّمَتْ عَلَيْكُمُ الْمَيْتَةُ وَالدَّمُ وَلَحْمُ الْخِنزِيرِ",
                textTranslation: "Prohibited to you are dead animals, blood, the flesh of swine, and that which has been dedicated to other than Allah.",
                textTransliteration: "Hurrimat 'alaykumu al-maytatu wa'd-damu wa lahmu al-khinzeer",
                revelationPlace: .medina, juzNumber: 6, hizbNumber: 11, rukuNumber: 1, manzilNumber: 2, pageNumber: 106,
                themes: ["prohibited", "food", "lawful", "unlawful", "dead animals", "blood", "swine", "dedicated"],
                keywords: ["prohibited", "dead", "animals", "blood", "flesh", "swine", "dedicated", "Allah"]
            ),
            QuranVerse(
                surahNumber: 6, surahName: "Al-An'am", surahNameArabic: "الأنعام",
                verseNumber: 145, textArabic: "قُل لَّا أَجِدُ فِي مَا أُوحِيَ إِلَيَّ مُحَرَّمًا",
                textTranslation: "Say, 'I do not find within that which was revealed to me [anything] forbidden to the one who would eat it unless it be a dead animal or blood spilled out or the flesh of swine.'",
                textTransliteration: "Qul la ajidu fi ma oohiya ilayya muharraman",
                revelationPlace: .mecca, juzNumber: 8, hizbNumber: 15, rukuNumber: 18, manzilNumber: 3, pageNumber: 148,
                themes: ["revelation", "forbidden", "food", "dead animal", "blood", "swine", "flesh"],
                keywords: ["revealed", "forbidden", "dead", "animal", "blood", "spilled", "flesh", "swine"]
            ),
            QuranVerse(
                surahNumber: 16, surahName: "An-Nahl", surahNameArabic: "النحل",
                verseNumber: 115, textArabic: "إِنَّمَا حَرَّمَ عَلَيْكُمُ الْمَيْتَةَ وَالدَّمَ وَلَحْمَ الْخِنزِيرِ",
                textTranslation: "He has only forbidden to you dead animals, blood, the flesh of swine, and that which has been dedicated to other than Allah.",
                textTransliteration: "Innama harrama 'alaykumu al-maytata wa'd-dama wa lahma al-khinzeer",
                revelationPlace: .mecca, juzNumber: 14, hizbNumber: 28, rukuNumber: 14, manzilNumber: 4, pageNumber: 278,
                themes: ["forbidden", "dead animals", "blood", "swine", "dedicated", "Allah"],
                keywords: ["forbidden", "dead", "animals", "blood", "flesh", "swine", "dedicated", "Allah"]
            ),
            QuranVerse(
                surahNumber: 17, surahName: "Al-Isra", surahNameArabic: "الإسراء",
                verseNumber: 70, textArabic: "وَلَقَدْ كَرَّمْنَا بَنِي آدَمَ وَحَمَلْنَاهُمْ فِي الْبَرِّ وَالْبَحْرِ",
                textTranslation: "And We have certainly honored the children of Adam and carried them on the land and sea and provided for them of the good things.",
                textTransliteration: "Wa laqad karramna bani Adama wa hamalnahum fi al-barri wa al-bahri",
                revelationPlace: .mecca, juzNumber: 15, hizbNumber: 30, rukuNumber: 9, manzilNumber: 4, pageNumber: 290,
                themes: ["honor", "children", "Adam", "land", "sea", "provision", "good things"],
                keywords: ["honored", "children", "Adam", "carried", "land", "sea", "provided", "good"]
            )
        ]
    }

    private func createSampleSurahs() -> [QuranSurah] {
        return [
            QuranSurah(
                number: 1, name: "Al-Fatiha", nameArabic: "الفاتحة",
                nameTransliteration: "Al-Faatihah", meaning: "The Opening",
                verseCount: 7, revelationPlace: .mecca, revelationOrder: 5,
                description: "The opening chapter of the Quran, recited in every prayer.",
                themes: ["prayer", "guidance", "mercy", "worship"]
            ),
            QuranSurah(
                number: 2, name: "Al-Baqarah", nameArabic: "البقرة",
                nameTransliteration: "Al-Baqarah", meaning: "The Cow",
                verseCount: 286, revelationPlace: .medina, revelationOrder: 87,
                description: "The longest chapter, covering law, guidance, and stories.",
                themes: ["law", "guidance", "stories", "faith"]
            ),
            QuranSurah(
                number: 112, name: "Al-Ikhlas", nameArabic: "الإخلاص",
                nameTransliteration: "Al-Ikhlaas", meaning: "The Sincerity",
                verseCount: 4, revelationPlace: .mecca, revelationOrder: 22,
                description: "Declaration of Allah's absolute unity and uniqueness.",
                themes: ["monotheism", "unity", "sincerity"]
            )
        ]
    }

    // MARK: - Debug Methods

    /// Test method to debug search functionality
    public func testSearch(query: String) {
        print("🔧 DEBUG: Testing search for '\(query)'")

        // Test semantic engine
        let correctedQuery = semanticEngine.correctTypos(in: query)
        print("🔧 DEBUG: Corrected query: '\(correctedQuery)'")

        let expandedTerms = semanticEngine.expandQuery(correctedQuery)
        print("🔧 DEBUG: Expanded terms: \(expandedTerms)")

        // Test famous verse check
        let famousResults = checkForFamousVerses(query: query)
        print("🔧 DEBUG: Famous verse results: \(famousResults.count)")

        // Test verse 2:255 specifically
        if let ayatAlKursi = allVerses.first(where: { $0.surahNumber == 2 && $0.verseNumber == 255 }) {
            print("🔧 DEBUG: Found Ayat al-Kursi verse")
            print("🔧 DEBUG: Keywords: \(ayatAlKursi.keywords)")
            print("🔧 DEBUG: Themes: \(ayatAlKursi.themes)")

            let matches = ayatAlKursi.contains(text: query)
            print("🔧 DEBUG: Direct contains check: \(matches)")

            let semanticMatches = ayatAlKursi.semanticallyMatches(query: query, expandedTerms: expandedTerms)
            print("🔧 DEBUG: Semantic matches: \(semanticMatches)")
        }
    }

    /// Test case-insensitive search functionality
    public func testCaseInsensitiveSearch() {
        print("🔧 DEBUG: === Testing Case-Insensitive Search ===")

        let testQueries = [
            "Ayat al-Kursi",
            "AYAT AL-KURSI",
            "ayat al-kursi",
            "Ayat Al-Kursi",
            "KURSI",
            "kursi",
            "Kursi",
            "THRONE VERSE",
            "throne verse",
            "Throne Verse"
        ]

        for query in testQueries {
            print("🔧 DEBUG: Testing query: '\(query)'")

            // Test famous verse recognition
            let famousResults = checkForFamousVerses(query: query)
            print("🔧 DEBUG: Famous verse matches: \(famousResults.count)")

            // Test semantic expansion
            let expandedTerms = semanticEngine.expandQuery(query)
            print("🔧 DEBUG: Expanded terms: \(expandedTerms)")

            // Test direct verse matching
            if let ayatAlKursi = allVerses.first(where: { $0.surahNumber == 2 && $0.verseNumber == 255 }) {
                let directMatch = ayatAlKursi.contains(text: query)
                let semanticMatch = ayatAlKursi.semanticallyMatches(query: query, expandedTerms: expandedTerms)
                print("🔧 DEBUG: Direct match: \(directMatch), Semantic match: \(semanticMatch)")
            }

            print("🔧 DEBUG: ---")
        }

        print("🔧 DEBUG: === End Case-Insensitive Test ===")
    }

    /// Comprehensive test for case-insensitive search functionality
    public func runCaseInsensitiveTests() async {
        print("🔧 DEBUG: === Running Comprehensive Case-Insensitive Tests ===")

        let testCases = [
            ("Ayat al-Kursi", "Mixed case with hyphens"),
            ("AYAT AL-KURSI", "All uppercase with hyphens"),
            ("ayat al-kursi", "All lowercase with hyphens"),
            ("Ayat Al-Kursi", "Title case with hyphens"),
            ("ayat al kursi", "Lowercase with spaces"),
            ("AYAT AL KURSI", "Uppercase with spaces"),
            ("Ayat Al Kursi", "Title case with spaces"),
            ("KURSI", "Single word uppercase"),
            ("kursi", "Single word lowercase"),
            ("Kursi", "Single word title case"),
            ("THRONE VERSE", "Alternative name uppercase"),
            ("throne verse", "Alternative name lowercase"),
            ("Throne Verse", "Alternative name title case")
        ]

        for (query, description) in testCases {
            print("🔧 DEBUG: Testing '\(query)' (\(description))")

            // Test the full search flow
            await searchVerses(query: query)

            let foundResults = !enhancedSearchResults.isEmpty
            let hasAyatAlKursi = enhancedSearchResults.contains { result in
                result.verse.surahNumber == 2 && result.verse.verseNumber == 255
            }

            print("🔧 DEBUG: Results found: \(foundResults), Contains Ayat al-Kursi: \(hasAyatAlKursi)")

            if hasAyatAlKursi {
                let ayatResult = enhancedSearchResults.first { $0.verse.surahNumber == 2 && $0.verse.verseNumber == 255 }
                print("🔧 DEBUG: Ayat al-Kursi relevance score: \(ayatResult?.relevanceScore ?? 0)")
                print("🔧 DEBUG: Match type: \(ayatResult?.matchType ?? .partial)")
            }

            print("🔧 DEBUG: ---")
        }

        print("🔧 DEBUG: === End Comprehensive Case-Insensitive Tests ===")
    }

    // MARK: - Public Search Methods
    
    /// Clear search results and related query state.
    @MainActor
    public func clearSearchState() {
        searchResults = []
        enhancedSearchResults = []
        lastQuery = ""
    }
    
    /// Perform comprehensive search across Quran verses
    public func searchVerses(query: String, searchOptions: QuranSearchOptions = QuranSearchOptions()) async {
        print("🔧 DEBUG: searchVerses called with query: '\(query)'")
        print("🔧 DEBUG: allVerses.count = \(allVerses.count)")
        print("🔧 DEBUG: isDataLoaded = \(isDataLoaded)")
        
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("🔧 DEBUG: Empty query, returning empty results")
            await MainActor.run {
                self.searchResults = []
                self.enhancedSearchResults = []
            }
            return
        }
        
        // Cancel any existing search task
        currentSearchTask?.cancel()
        
        await MainActor.run {
            self.isLoading = true
            self.error = nil
            self.lastQuery = query
        }

        do {
            try await ensureDataAvailability()
        } catch {
            await MainActor.run {
                self.error = error
                self.searchResults = []
                self.enhancedSearchResults = []
                self.isLoading = false
            }
            return
        }
        
        // Create new search task
        currentSearchTask = Task {
            do {
                // Check for cancellation before starting
                try Task.checkCancellation()
                
                // Perform search with slight delay to simulate processing
                try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                
                // Check for cancellation after delay
                try Task.checkCancellation()
                
                // Use semantic search for enhanced results
                let results = await performSemanticSearch(query: query, options: searchOptions)
                print("🔧 DEBUG: performSemanticSearch returned \(results.count) results")
                
                // Check for cancellation before updating results
                try Task.checkCancellation()
                
                // Update results and search history on main thread
                await MainActor.run {
                    self.enhancedSearchResults = results.sorted { $0.combinedScore > $1.combinedScore }
                    
                    // Also maintain legacy results for backward compatibility
                    self.searchResults = results.map { enhancedResult in
                        QuranSearchResult(
                            verse: enhancedResult.verse,
                            relevanceScore: enhancedResult.relevanceScore,
                            matchedText: enhancedResult.matchedText,
                            matchType: enhancedResult.matchType,
                            highlightedText: enhancedResult.highlightedText,
                            contextSuggestions: enhancedResult.contextSuggestions
                        )
                    }
                    
                    // Add to search history AFTER search completion on main thread
                    self.addToSearchHistory(query)
                    self.isLoading = false
                }
                
                print("🔧 DEBUG: Final search results count: \(self.searchResults.count)")
                
            } catch is CancellationError {
                print("🔧 DEBUG: Search was cancelled for query: '\(query)'")
                await MainActor.run {
                    self.isLoading = false
                }
            } catch {
                print("🔧 DEBUG: Search error: \(error)")
                await MainActor.run {
                    self.error = error
                    self.searchResults = []
                    self.enhancedSearchResults = []
                    self.isLoading = false
                }
            }
        }
        
        // Wait for the search task to complete
        do {
            try await currentSearchTask?.value
        } catch is CancellationError {
            // Cancellation is expected, don't treat as error
            print("🔧 DEBUG: Search task cancelled")
        } catch {
            print("🔧 DEBUG: Search task error: \(error)")
        }
    }
    
    /// Check for famous verse names first
    private func checkForFamousVerses(query: String) -> [EnhancedSearchResult] {
        let queryLower = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Famous verse mappings - using safe initialization to prevent duplicate key crashes
        let famousVerses = createFamousVersesMappings()

        // Check if query matches any famous verse (case-insensitive)
        for (name, location) in famousVerses {
            // Exact match check (case-insensitive)
            if queryLower == name {
                if let verse = allVerses.first(where: { $0.surahNumber == location.surah && $0.verseNumber == location.verse }) {
                    print("🔧 DEBUG: Found exact famous verse match: '\(name)' -> \(verse.shortReference)")
                    return [EnhancedSearchResult(
                        verse: verse,
                        relevanceScore: 10.0,
                        semanticScore: 10.0,
                        matchedText: name,
                        matchType: .exact,
                        highlightedText: verse.textTranslation,
                        contextSuggestions: [name, "monotheism", "unity", "protection"],
                        queryExpansion: QueryExpansion(
                            originalQuery: name,
                            expandedTerms: [name, "monotheism", "unity"],
                            relatedConcepts: ["Tawhid", "Oneness"],
                            suggestions: ["search by verse reference", "search by theme"]
                        ),
                        relatedVerses: verse.getRelatedVerses(from: allVerses, limit: 3)
                    )]
                }
            }

            // Partial match check (case-insensitive)
            if queryLower.contains(name) || name.contains(queryLower) {
                if let verse = allVerses.first(where: { $0.surahNumber == location.surah && $0.verseNumber == location.verse }) {
                    print("🔧 DEBUG: Found partial famous verse match: '\(name)' -> \(verse.shortReference)")
                    return [EnhancedSearchResult(
                        verse: verse,
                        relevanceScore: 9.0, // Slightly lower for partial matches
                        semanticScore: 9.0,
                        matchedText: name,
                        matchType: .semantic,
                        highlightedText: verse.textTranslation,
                        contextSuggestions: [name, "monotheism", "unity", "protection"],
                        queryExpansion: QueryExpansion(
                            originalQuery: name,
                            expandedTerms: [name, "monotheism", "unity"],
                            relatedConcepts: ["Tawhid", "Oneness"],
                            suggestions: ["search by verse reference", "search by theme"]
                        ),
                        relatedVerses: verse.getRelatedVerses(from: allVerses, limit: 3)
                    )]
                }
            }
        }

        return []
    }

    /// Perform semantic search with expanded query terms
    private func performSemanticSearch(query: String, options: QuranSearchOptions) async -> [EnhancedSearchResult] {
        print("🔧 DEBUG: performSemanticSearch called with query: '\(query)'")
        print("🔧 DEBUG: Processing \(allVerses.count) verses")

        // First check for famous verses
        let famousResults = checkForFamousVerses(query: query)
        if !famousResults.isEmpty {
            print("🔧 DEBUG: Found \(famousResults.count) famous verse matches")
            return famousResults
        }

        // Correct typos
        let correctedQuery = semanticEngine.correctTypos(in: query)
        print("🔧 DEBUG: Corrected query: '\(correctedQuery)'")

        // Expand query with synonyms and related terms
        let expandedTerms = semanticEngine.expandQuery(correctedQuery)
        print("🔧 DEBUG: Expanded terms: \(expandedTerms)")
        
        // Determine query type
        let queryType = determineQueryType(query)
        print("🔧 DEBUG: Query type: \(queryType)")
        
        // Create query expansion object
        let expansion = QueryExpansion(
            originalQuery: query,
            expandedTerms: expandedTerms,
            relatedConcepts: semanticEngine.getRelatedConcepts(for: correctedQuery),
            suggestions: semanticEngine.getSearchSuggestions(for: correctedQuery),
            correctedQuery: correctedQuery != query ? correctedQuery : nil,
            queryType: queryType
        )
        
        await MainActor.run {
            self.queryExpansion = expansion
        }
        
        var results: [EnhancedSearchResult] = []
        
        for (index, verse) in allVerses.enumerated() {
            // Special debug for verse 2:255 (Ayat al-Kursi)
            if verse.surahNumber == 2 && verse.verseNumber == 255 {
                print("🔧 DEBUG: Checking Ayat al-Kursi (2:255)")
                print("🔧 DEBUG: Original query: '\(expansion.originalQuery)'")
                print("🔧 DEBUG: Expanded terms: \(expansion.expandedTerms)")
                print("🔧 DEBUG: Verse keywords: \(verse.keywords)")
                print("🔧 DEBUG: Verse themes: \(verse.themes)")

                let matches = verse.semanticallyMatches(query: expansion.originalQuery, expandedTerms: expansion.expandedTerms)
                print("🔧 DEBUG: Ayat al-Kursi semantically matches: \(matches)")

                // Test individual terms
                for term in [expansion.originalQuery] + expansion.expandedTerms {
                    let termMatches = verse.contains(text: term)
                    print("🔧 DEBUG: Term '\(term)' matches: \(termMatches)")
                }
            }

            if let result = evaluateVerseSemanticallly(verse, expansion: expansion, options: options) {
                results.append(result)
                if index < 5 { // Log first 5 matches for debugging
                    print("🔧 DEBUG: Match found at verse \(verse.shortReference): \(result.matchType)")
                }
            }
        }
        
        print("🔧 DEBUG: Found \(results.count) semantic matches")
        return results
    }
    
    /// Evaluate verse using semantic search
    private func evaluateVerseSemanticallly(_ verse: QuranVerse, expansion: QueryExpansion, options: QuranSearchOptions) -> EnhancedSearchResult? {
        // Check if verse matches using expanded terms
        guard verse.semanticallyMatches(query: expansion.originalQuery, expandedTerms: expansion.expandedTerms) else {
            return nil
        }
        
        // Calculate relevance score (original method)
        let relevanceScore = calculateRelevanceScore(verse, query: expansion.originalQuery, options: options)
        
        // Calculate semantic score using expanded terms
        let semanticScore = verse.semanticRelevanceScore(for: expansion.originalQuery, expandedTerms: expansion.expandedTerms)
        
        guard relevanceScore > 0 || semanticScore > 0 else { return nil }
        
        // Determine match type
        let matchType = determineMatchType(verse, query: expansion.originalQuery, expandedTerms: expansion.expandedTerms)
        
        // Generate highlighted text
        let highlightedText = generateHighlightedText(verse, query: expansion.originalQuery, expandedTerms: expansion.expandedTerms)
        
        // Find related verses
        let relatedVerses = verse.getRelatedVerses(from: allVerses, limit: 3)
        
        // Generate context suggestions
        let contextSuggestions = generateContextSuggestions(for: verse, expansion: expansion)
        
        return EnhancedSearchResult(
            verse: verse,
            relevanceScore: relevanceScore,
            semanticScore: semanticScore,
            matchedText: expansion.originalQuery,
            matchType: matchType,
            highlightedText: highlightedText,
            contextSuggestions: contextSuggestions,
            queryExpansion: expansion,
            relatedVerses: relatedVerses
        )
    }
    
    /// Generate real-time search suggestions
    public func generateSearchSuggestions(for partialQuery: String) {
        guard !partialQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            Task { @MainActor in
                self.searchSuggestions = []
            }
            return
        }
        
        Task { @MainActor in
            self.searchSuggestions = semanticEngine.getSearchSuggestions(for: partialQuery)
        }
    }
    
    /// Get intelligent search suggestions based on context
    public func getIntelligentSuggestions(for query: String) -> [String] {
        let expandedTerms = semanticEngine.expandQuery(query)
        let relatedConcepts = semanticEngine.getRelatedConcepts(for: query)
        
        var suggestions: Set<String> = []
        
        // Add expanded terms
        suggestions.formUnion(expandedTerms)
        
        // Add related concepts
        suggestions.formUnion(relatedConcepts)
        
        // Add theme-based suggestions
        for verse in allVerses {
            if verse.contains(text: query) {
                suggestions.formUnion(verse.themes)
                suggestions.formUnion(verse.keywords)
            }
        }
        
        // Remove the original query and return top suggestions
        suggestions.remove(query.lowercased())
        return Array(suggestions).sorted().prefix(8).map { $0 }
    }
    
    /// Search by Surah and verse reference (e.g., "2:255" or "Al-Baqarah 255")
    public func searchByReference(_ reference: String) async {
        // Cancel any existing search task
        currentSearchTask?.cancel()
        
        await MainActor.run {
            self.isLoading = true
            self.error = nil
            self.lastQuery = reference
        }

        do {
            try await ensureDataAvailability()
        } catch {
            await MainActor.run {
                self.error = error
                self.searchResults = []
                self.enhancedSearchResults = []
                self.isLoading = false
            }
            return
        }
        
        // Create new search task for reference search
        currentSearchTask = Task {
            do {
                // Check for cancellation
                try Task.checkCancellation()
                
                let results = searchByVerseReference(reference)
                
                // Check for cancellation before updating results
                try Task.checkCancellation()
                
                await MainActor.run {
                    self.searchResults = results
                    // Convert to enhanced results for consistency
                    self.enhancedSearchResults = results.map { result in
                        EnhancedSearchResult(
                            verse: result.verse,
                            relevanceScore: result.relevanceScore,
                            semanticScore: result.relevanceScore,
                            matchedText: result.matchedText,
                            matchType: result.matchType,
                            highlightedText: result.highlightedText,
                            contextSuggestions: result.contextSuggestions,
                            queryExpansion: QueryExpansion(
                                originalQuery: reference,
                                expandedTerms: [],
                                relatedConcepts: [],
                                suggestions: []
                            ),
                            relatedVerses: []
                        )
                    }
                    // Add to search history
                    self.addToSearchHistory(reference)
                    self.isLoading = false
                }
                
            } catch is CancellationError {
                print("🔧 DEBUG: Reference search was cancelled for: '\(reference)'")
                await MainActor.run {
                    self.isLoading = false
                }
            } catch {
                print("🔧 DEBUG: Reference search error: \(error)")
                await MainActor.run {
                    self.error = error
                    self.searchResults = []
                    self.enhancedSearchResults = []
                    self.isLoading = false
                }
            }
        }
        
        // Wait for the search task to complete
        do {
            try await currentSearchTask?.value
        } catch is CancellationError {
            print("🔧 DEBUG: Reference search task cancelled")
        } catch {
            print("🔧 DEBUG: Reference search task error: \(error)")
        }
    }
    
    /// Get verses from a specific Surah
    public func getVersesFromSurah(_ surahNumber: Int, verseRange: ClosedRange<Int>? = nil) -> [QuranVerse] {
        // Trigger data loading if not already loaded
        ensureDataLoaded()
        
        let surahVerses = allVerses.filter { $0.surahNumber == surahNumber }
        
        if let range = verseRange {
            return surahVerses.filter { range.contains($0.verseNumber) }
        }
        
        return surahVerses.sorted { $0.verseNumber < $1.verseNumber }
    }
    
    /// Get all Surahs with basic information
    public func getAllSurahs() -> [QuranSurah] {
        // Trigger data loading if not already loaded
        ensureDataLoaded()
        
        return allSurahs.sorted { $0.number < $1.number }
    }
    
    // MARK: - Bookmark Management
    
    public func toggleBookmark(for verse: QuranVerse) {
        if let index = bookmarkedVerses.firstIndex(where: { $0.id == verse.id }) {
            bookmarkedVerses.remove(at: index)
        } else {
            bookmarkedVerses.append(verse)
        }
        saveBookmarkedVerses()
    }
    
    public func isBookmarked(_ verse: QuranVerse) -> Bool {
        return bookmarkedVerses.contains { $0.id == verse.id }
    }

    // MARK: - Data Management

    /// Refresh Quran data from API
    public func refreshQuranData() {
        print("🔄 Refreshing Quran data from API...")
        cacheManager.clearCache()
        
        // Reset state
        allVerses.removeAll()
        allSurahs.removeAll()
        isDataLoaded = false
        error = nil
        dataValidationResult = nil
        
        loadCompleteQuranData()
    }

    /// Get data validation status
    public func getDataValidationStatus() -> QuranDataValidator.ValidationResult? {
        return dataValidationResult
    }

    /// Check if complete Quran data is loaded
    public func isCompleteDataLoaded() -> Bool {
        return isDataLoaded && allVerses.count == QuranDataValidator.EXPECTED_TOTAL_VERSES
    }

    /// Get data loading progress (0.0 to 1.0)
    public func getLoadingProgress() -> Double {
        return loadingProgress
    }

    /// Get total verses count
    public func getTotalVersesCount() -> Int {
        return allVerses.count
    }

    /// Get number of currently loaded verses (alias for total for clarity)
    public func getLoadedVersesCount() -> Int {
        return allVerses.count
    }

    /// Get total surahs count
    public func getTotalSurahsCount() -> Int {
        return allSurahs.count
    }

    /// Force reload data (useful for testing)
    public func forceReloadData() {
        allVerses.removeAll()
        allSurahs.removeAll()
        isDataLoaded = false
        cacheManager.clearCache()
        loadCompleteQuranData()
    }

    // MARK: - Search History Management
    
    public func clearSearchHistory() {
        searchHistory.removeAll()
        userDefaults.removeObject(forKey: CacheKeys.searchHistory)
    }
    
    public func removeFromHistory(_ query: String) {
        searchHistory.removeAll { $0 == query }
        saveSearchHistory()
    }
    
    // MARK: - Private Methods
    
    private func performSearch(query: String, options: QuranSearchOptions) -> [QuranSearchResult] {
        let lowercasedQuery = query.lowercased()
        var results: [QuranSearchResult] = []
        
        for verse in allVerses {
            if let result = evaluateVerse(verse, for: lowercasedQuery, options: options) {
                results.append(result)
            }
        }
        
        return results
    }
    
    /// Determine the type of query being performed
    private func determineQueryType(_ query: String) -> QueryType {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanQueryLower = cleanQuery.lowercased()

        // Check if it's a reference (e.g., "2:255", "Al-Baqarah 255")
        if cleanQuery.contains(":") && cleanQuery.components(separatedBy: ":").count == 2 {
            return .reference
        }

        // Check if it's a question (case-insensitive)
        if cleanQueryLower.hasPrefix("what") || cleanQueryLower.hasPrefix("how") || cleanQueryLower.hasPrefix("why") || cleanQueryLower.hasPrefix("when") || cleanQueryLower.hasPrefix("where") {
            return .question
        }
        
        // Check if it contains Arabic characters
        if cleanQuery.rangeOfCharacter(from: CharacterSet(charactersIn: "ابتثجحخدذرزسشصضطظعغفقكلمنهوي")) != nil {
            return .arabic
        }
        
        // Check if it's a common theme (case-insensitive)
        let commonThemes = ["prayer", "mercy", "guidance", "patience", "forgiveness", "paradise", "hell", "death", "life", "love", "fear", "knowledge", "wisdom", "justice", "peace"]
        if commonThemes.contains(cleanQueryLower) {
            return .theme
        }
        
        // Check if it's a concept
        let commonConcepts = ["allah", "god", "lord", "creator", "faith", "belief", "worship", "devotion", "community", "family", "charity", "gratitude"]
        if commonConcepts.contains(cleanQuery.lowercased()) {
            return .concept
        }
        
        return .general
    }
    
    /// Calculate relevance score for a verse
    private func calculateRelevanceScore(_ verse: QuranVerse, query: String, options: QuranSearchOptions) -> Double {
        var score: Double = 0
        let lowercasedQuery = query.lowercased()
        
        // Check translation match
        if options.searchTranslation && verse.textTranslation.lowercased().contains(lowercasedQuery) {
            score += calculateTranslationScore(verse.textTranslation, query: lowercasedQuery)
        }
        
        // Check Arabic text match
        if options.searchArabic && verse.textArabic.lowercased().contains(lowercasedQuery) {
            score += 10.0 // Higher score for Arabic matches
        }
        
        // Check transliteration match
        if options.searchTransliteration,
           let transliteration = verse.textTransliteration,
           transliteration.lowercased().contains(lowercasedQuery) {
            score += 8.0
        }
        
        // Check theme match
        if options.searchThemes && verse.themes.contains(where: { $0.lowercased().contains(lowercasedQuery) }) {
            score += 6.0
        }
        
        // Check keyword match
        if options.searchKeywords && verse.keywords.contains(where: { $0.lowercased().contains(lowercasedQuery) }) {
            score += 5.0
        }
        
        // Check Surah name match
        if verse.surahName.lowercased().contains(lowercasedQuery) || verse.surahNameArabic.contains(lowercasedQuery) {
            score += 4.0
        }
        
        return score
    }
    
    /// Determine match type for semantic search
    private func determineMatchType(_ verse: QuranVerse, query: String, expandedTerms: [String]) -> MatchType {
        let queryLower = query.lowercased()
        
        // Check exact match in translation
        if verse.textTranslation.lowercased().contains(queryLower) {
            return .exact
        }
        
        // Check exact match in Arabic
        if verse.textArabic.lowercased().contains(queryLower) {
            return .exact
        }
        
        // Check exact match in transliteration
        if verse.textTransliteration?.lowercased().contains(queryLower) ?? false {
            return .exact
        }
        
        // Check if any expanded term matches exactly
        for term in expandedTerms {
            if verse.textTranslation.lowercased().contains(term.lowercased()) {
                return .semantic
            }
        }
        
        // Check theme match
        if verse.themes.contains(where: { $0.lowercased().contains(queryLower) }) {
            return .thematic
        }
        
        // Check keyword match
        if verse.keywords.contains(where: { $0.lowercased().contains(queryLower) }) {
            return .keyword
        }
        
        return .partial
    }
    
    /// Generate highlighted text with matched terms
    private func generateHighlightedText(_ verse: QuranVerse, query: String, expandedTerms: [String]) -> String {
        var highlightedText = verse.textTranslation
        let allTerms = [query] + expandedTerms
        
        for term in allTerms {
            let safeTerm = term.replacingOccurrences(of: "*", with: "\\*")
            highlightedText = highlightedText.replacingOccurrences(
                of: term,
                with: "***\(safeTerm)***",
                options: .caseInsensitive
            )
        }
        
        return highlightedText
    }
    
    /// Generate context suggestions for a verse
    private func generateContextSuggestions(for verse: QuranVerse, expansion: QueryExpansion) -> [String] {
        var suggestions: [String] = []
        
        // Add expanded terms as suggestions
        suggestions.append(contentsOf: expansion.expandedTerms.prefix(3))
        
        // Add related concepts
        suggestions.append(contentsOf: expansion.relatedConcepts.prefix(2))
        
        // Add verse themes
        suggestions.append(contentsOf: verse.themes.prefix(2))
        
        // Add Surah-based suggestion
        suggestions.append("More from \(verse.surahName)")
        
        // Add Juz-based suggestion
        suggestions.append("Juz \(verse.juzNumber)")
        
        // Remove duplicates and return top suggestions
        let uniqueSuggestions = Array(Set(suggestions))
        return Array(uniqueSuggestions.prefix(6))
    }
    
    private func evaluateVerse(_ verse: QuranVerse, for query: String, options: QuranSearchOptions) -> QuranSearchResult? {
        var score: Double = 0
        var matchType: MatchType = .partial
        var matchedText = query
        var highlightedText = verse.textTranslation
        
        // Check translation match
        if options.searchTranslation && verse.textTranslation.lowercased().contains(query) {
            score += calculateTranslationScore(verse.textTranslation, query: query)
            matchType = .exact
            highlightedText = highlightMatches(in: verse.textTranslation, query: query)
        }
        
        // Check Arabic text match
        if options.searchArabic && verse.textArabic.lowercased().contains(query) {
            score += 10.0 // Higher score for Arabic matches
            matchType = .exact
        }
        
        // Check transliteration match
        if options.searchTransliteration,
           let transliteration = verse.textTransliteration,
           transliteration.lowercased().contains(query) {
            score += 8.0
            matchType = .exact
        }
        
        // Check theme match
        if options.searchThemes && verse.themes.contains(where: { $0.lowercased().contains(query) }) {
            score += 6.0
            matchType = .thematic
        }
        
        // Check keyword match
        if options.searchKeywords && verse.keywords.contains(where: { $0.lowercased().contains(query) }) {
            score += 5.0
            matchType = .keyword
        }
        
        // Check Surah name match
        if verse.surahName.lowercased().contains(query) || verse.surahNameArabic.contains(query) {
            score += 4.0
            matchType = .semantic
        }
        
        guard score > 0 else { return nil }
        
        return QuranSearchResult(
            verse: verse,
            relevanceScore: score,
            matchedText: matchedText,
            matchType: matchType,
            highlightedText: highlightedText,
            contextSuggestions: generateContextSuggestions(for: verse)
        )
    }
    
    private func calculateTranslationScore(_ text: String, query: String) -> Double {
        let words = query.components(separatedBy: .whitespacesAndNewlines)
        let textWords = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
        
        var score: Double = 0
        
        for word in words {
            if textWords.contains(word.lowercased()) {
                score += 2.0
            }
            
            // Partial word matches
            for textWord in textWords {
                if textWord.contains(word.lowercased()) {
                    score += 1.0
                }
            }
        }
        
        // Bonus for phrase matches
        if text.lowercased().contains(query) {
            score += 5.0
        }
        
        return score
    }
    
    private func highlightMatches(in text: String, query: String) -> String {
        let safeQuery = query.replacingOccurrences(of: "*", with: "\\*")
        return text.replacingOccurrences(
            of: query,
            with: "***\(safeQuery)***",
            options: .caseInsensitive
        )
    }
    
    private func generateContextSuggestions(for verse: QuranVerse) -> [String] {
        var suggestions: [String] = []
        
        // Add theme-based suggestions
        suggestions.append(contentsOf: verse.themes.prefix(3))
        
        // Add Surah-based suggestion
        suggestions.append("More from \(verse.surahName)")
        
        // Add Juz-based suggestion
        suggestions.append("Juz \(verse.juzNumber)")
        
        return Array(suggestions.prefix(5))
    }
    
    private func searchByVerseReference(_ reference: String) -> [QuranSearchResult] {
        // Parse reference like "2:255" or "Al-Baqarah 255"
        let components = reference.components(separatedBy: CharacterSet(charactersIn: ": "))
        
        if components.count >= 2 {
            // Try numeric reference first (e.g., "2:255")
            if let surahNum = Int(components[0]), let verseNum = Int(components[1]) {
                if let verse = allVerses.first(where: { $0.surahNumber == surahNum && $0.verseNumber == verseNum }) {
                    return [QuranSearchResult(
                        verse: verse,
                        relevanceScore: 10.0,
                        matchedText: reference,
                        matchType: .exact,
                        highlightedText: verse.textTranslation
                    )]
                }
            }
            
            // Try Surah name reference
            let surahName = components[0]
            if let verseNum = Int(components[1]) {
                if let verse = allVerses.first(where: { 
                    ($0.surahName.lowercased().contains(surahName.lowercased()) || 
                     $0.surahNameArabic.contains(surahName)) && 
                    $0.verseNumber == verseNum 
                }) {
                    return [QuranSearchResult(
                        verse: verse,
                        relevanceScore: 10.0,
                        matchedText: reference,
                        matchType: .exact,
                        highlightedText: verse.textTranslation
                    )]
                }
            }
        }
        
        return []
    }
    
    private func addToSearchHistory(_ query: String) {
        // Remove if already exists
        searchHistory.removeAll { $0 == query }
        
        // Add to beginning
        searchHistory.insert(query, at: 0)
        
        // Limit history size
        if searchHistory.count > maxHistoryItems {
            searchHistory = Array(searchHistory.prefix(maxHistoryItems))
        }
        
        saveSearchHistory()
    }
    
    private func saveSearchHistory() {
        userDefaults.set(searchHistory, forKey: CacheKeys.searchHistory)
    }
    
    private func loadSearchHistory() {
        searchHistory = userDefaults.stringArray(forKey: CacheKeys.searchHistory) ?? []
    }
    
    private func saveBookmarkedVerses() {
        if let data = try? JSONEncoder().encode(bookmarkedVerses) {
            userDefaults.set(data, forKey: CacheKeys.bookmarkedVerses)
        }
    }
    
    private func loadBookmarkedVerses() {
        if let data = userDefaults.data(forKey: CacheKeys.bookmarkedVerses),
           let verses = try? JSONDecoder().decode([QuranVerse].self, from: data) {
            bookmarkedVerses = verses
        }
    }
    
    /// Create famous verses mappings with safe initialization to prevent duplicate key crashes
    private func createFamousVersesMappings() -> [String: (surah: Int, verse: Int)] {
        var famousVerses: [String: (surah: Int, verse: Int)] = [:]
        var duplicatesFound: [String] = []
        
        // Define the verse mappings as array of tuples to avoid duplicate key issues
        let mappings: [(String, Int, Int)] = [
            // Ayat al-Kursi (Throne Verse) - 2:255
            ("ayat al-kursi", 2, 255),
            ("ayat al kursi", 2, 255),
            ("ayatul kursi", 2, 255),
            ("ayat ul kursi", 2, 255),
            ("throne verse", 2, 255),
            ("kursi", 2, 255),
            ("throne", 2, 255),
            ("sustainer verse", 2, 255),

            // Al-Fatiha (The Opening) - 1:1-7
            ("al-fatiha", 1, 1),
            ("fatiha", 1, 1),
            ("opening", 1, 1),
            ("bismillah", 1, 1),
            ("opening verse", 1, 1),
            ("mother of the book", 1, 1),

            // Light Verse (Ayat an-Nur) - 24:35
            ("light verse", 24, 35),
            ("ayat an-nur", 24, 35),
            ("ayat an nur", 24, 35),
            ("nur verse", 24, 35),
            ("allah is light", 24, 35),

            // Ikhlas (Sincerity) - 112:1-4
            ("ikhlas", 112, 1),
            ("sincerity", 112, 1),
            ("purity", 112, 1),
            ("say he is allah one", 112, 1),

            // Al-Falaq (The Daybreak) - 113:1-5
            ("falaq", 113, 1),
            ("daybreak", 113, 1),
            ("dawn", 113, 1),
            ("refuge", 113, 1),

            // An-Nas (Mankind) - 114:1-6
            ("nas", 114, 1),
            ("mankind", 114, 1),
            ("people", 114, 1),

            // Death Verse - 3:185
            ("death verse", 3, 185),
            ("every soul will taste death", 3, 185),
            ("taste death", 3, 185),

            // Burden Verse - 2:286
            ("burden verse", 2, 286),
            ("allah does not burden", 2, 286),
            ("does not charge", 2, 286),
            ("capacity", 2, 286)
        ]
        
        // Safely add mappings, handling potential duplicates
        for (key, surah, verse) in mappings {
            if famousVerses[key] != nil {
                let warningMessage = "Duplicate key detected in famous verses: '\(key)' - skipping duplicate"
                print("⚠️ WARNING: \(warningMessage)")
                duplicatesFound.append(key)
                continue
            }
            famousVerses[key] = (surah: surah, verse: verse)
        }
        
        // Report duplicates if found
        if !duplicatesFound.isEmpty {
            let errorMessage = "Found \(duplicatesFound.count) duplicate keys: \(duplicatesFound.joined(separator: ", "))"
            print("🚨 CRITICAL: \(errorMessage)")
            // Don't throw error - just log and continue with unique keys
        }
        
        print("✅ Famous verses mappings created successfully with \(famousVerses.count) entries")
        return famousVerses
    }
}

// MARK: - Search Options

public struct QuranSearchOptions {
    public var searchTranslation: Bool = true
    public var searchArabic: Bool = true
    public var searchTransliteration: Bool = true
    public var searchThemes: Bool = true
    public var searchKeywords: Bool = true
    public var maxResults: Int = 50
    
    public init() {}
}
