import Foundation
import Combine
import AVFoundation
import UIKit

/// Real implementation of TasbihServiceProtocol
@MainActor
public class TasbihService: TasbihServiceProtocol, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var currentSession: TasbihSession?
    @Published public var currentCount: Int = 0
    @Published public var availableDhikr: [Dhikr] = []
    @Published public var recentSessions: [TasbihSession] = []
    @Published public var statistics: TasbihStatistics = TasbihStatistics()
    @Published public var isLoading: Bool = false
    @Published public var error: Error? = nil
    @Published public var currentCounter: TasbihCounter = TasbihCounter(name: "Default")
    @Published public var availableCounters: [TasbihCounter] = []
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()
    private var sessionTimer: Timer?
    private var audioPlayer: AVAudioPlayer?
    
    // MARK: - UserDefaults Keys
    
    private enum CacheKeys {
        static let dhikrList = "tasbih_dhikr_list"
        static let sessions = "tasbih_sessions"
        static let counters = "tasbih_counters"
        static let goals = "tasbih_goals"
        static let currentSession = "tasbih_current_session"
        static let settings = "tasbih_settings"
        static let statistics = "tasbih_statistics"
    }
    
    // MARK: - Initialization
    
    public init() {
        setupDefaultData()
        loadCachedData()
        setupObservers()
    }
    
    deinit {
        sessionTimer?.invalidate()
    }
    
    // MARK: - Setup Methods
    
    private func setupDefaultData() {
        // Setup default dhikr
        let defaultDhikr = [
            Dhikr(
                arabicText: "سُبْحَانَ اللَّهِ",
                transliteration: "SubhanAllah",
                translation: "Glory be to Allah",
                category: .tasbih,
                reward: "Whoever says SubhanAllah 100 times, his sins are forgiven even if they are like the foam of the sea",
                source: "Sahih Muslim",
                targetCount: 33
            ),
            Dhikr(
                arabicText: "الْحَمْدُ لِلَّهِ",
                transliteration: "Alhamdulillah",
                translation: "All praise is due to Allah",
                category: .tahmid,
                reward: "Alhamdulillah fills the scales of good deeds",
                source: "Sahih Muslim",
                targetCount: 33
            ),
            Dhikr(
                arabicText: "اللَّهُ أَكْبَرُ",
                transliteration: "Allahu Akbar",
                translation: "Allah is the Greatest",
                category: .takbir,
                reward: "Takbir is beloved to Allah",
                source: "Sahih Bukhari",
                targetCount: 34
            ),
            Dhikr(
                arabicText: "لَا إِلَهَ إِلَّا اللَّهُ",
                transliteration: "La ilaha illa Allah",
                translation: "There is no god but Allah",
                category: .tahlil,
                reward: "The best dhikr is La ilaha illa Allah",
                source: "Sunan at-Tirmidhi",
                targetCount: 100
            ),
            Dhikr(
                arabicText: "أَسْتَغْفِرُ اللَّهَ",
                transliteration: "Astaghfirullah",
                translation: "I seek forgiveness from Allah",
                category: .istighfar,
                reward: "Whoever seeks forgiveness regularly, Allah will provide a way out of every difficulty",
                source: "Sunan Abu Dawood",
                targetCount: 100
            )
        ]
        
        // Setup default counters
        let defaultCounters = [
            TasbihCounter(name: "Default", maxCount: 99, isDefault: true),
            TasbihCounter(name: "33 Count", maxCount: 33),
            TasbihCounter(name: "100 Count", maxCount: 100),
            TasbihCounter(name: "Unlimited", maxCount: 9999)
        ]
        
        availableDhikr = defaultDhikr
        availableCounters = defaultCounters
        currentCounter = defaultCounters.first { $0.isDefault } ?? defaultCounters[0]
    }
    
    private func setupObservers() {
        // Observe app lifecycle for session management
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.pauseSession()
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadCachedData() {
        // Load dhikr
        if let data = userDefaults.data(forKey: CacheKeys.dhikrList),
           let dhikr = try? JSONDecoder().decode([Dhikr].self, from: data) {
            availableDhikr = dhikr
        }
        
        // Load sessions
        if let data = userDefaults.data(forKey: CacheKeys.sessions),
           let sessions = try? JSONDecoder().decode([TasbihSession].self, from: data) {
            recentSessions = Array(sessions.suffix(50)) // Keep last 50 sessions
        }
        
        // Load current session
        if let data = userDefaults.data(forKey: CacheKeys.currentSession),
           let session = try? JSONDecoder().decode(TasbihSession.self, from: data) {
            currentSession = session
            currentCount = session.currentCount
        }
        
        // Load counters
        if let data = userDefaults.data(forKey: CacheKeys.counters),
           let counters = try? JSONDecoder().decode([TasbihCounter].self, from: data) {
            availableCounters = counters
        }
        
        // Load statistics
        if let data = userDefaults.data(forKey: CacheKeys.statistics),
           let stats = try? JSONDecoder().decode(TasbihStatistics.self, from: data) {
            statistics = stats
        }
    }
    
    // MARK: - Session Management
    
    public func startSession(with dhikr: Dhikr, targetCount: Int? = nil, counter: TasbihCounter? = nil) async {
        isLoading = true
        error = nil
        
        do {
            // End current session if exists
            if currentSession != nil {
                await completeSession(notes: nil, mood: nil)
            }
            
            let session = TasbihSession(
                dhikr: dhikr,
                targetCount: targetCount ?? dhikr.targetCount
            )
            
            currentSession = session
            currentCount = 0
            
            if let counter = counter {
                currentCounter = counter
            }
            
            // Start session timer
            startSessionTimer()
            
            // Save current session
            try saveCachedData()
            
            // Provide haptic feedback
            if currentCounter.hapticFeedback {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }
            
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    public func pauseSession() async {
        guard var session = currentSession else { return }
        
        session = TasbihSession(
            id: session.id,
            dhikr: session.dhikr,
            startTime: session.startTime,
            endTime: session.endTime,
            currentCount: session.currentCount,
            targetCount: session.targetCount,
            isCompleted: session.isCompleted,
            isPaused: true,
            totalDuration: session.totalDuration,
            notes: session.notes,
            location: session.location,
            mood: session.mood
        )
        
        currentSession = session
        sessionTimer?.invalidate()
        
        do {
            try saveCachedData()
        } catch {
            self.error = error
        }
    }
    
    public func resumeSession() async {
        guard var session = currentSession else { return }
        
        session = TasbihSession(
            id: session.id,
            dhikr: session.dhikr,
            startTime: session.startTime,
            endTime: session.endTime,
            currentCount: session.currentCount,
            targetCount: session.targetCount,
            isCompleted: session.isCompleted,
            isPaused: false,
            totalDuration: session.totalDuration,
            notes: session.notes,
            location: session.location,
            mood: session.mood
        )
        
        currentSession = session
        startSessionTimer()
        
        do {
            try saveCachedData()
        } catch {
            self.error = error
        }
    }
    
    public func completeSession(notes: String? = nil, mood: SessionMood? = nil) async {
        guard var session = currentSession else { return }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(session.startTime)
        let didReachTarget = currentCount >= session.targetCount

        session = TasbihSession(
            id: session.id,
            dhikr: session.dhikr,
            startTime: session.startTime,
            endTime: endTime,
            currentCount: currentCount,
            targetCount: session.targetCount,
            isCompleted: didReachTarget,
            isPaused: false,
            totalDuration: duration,
            notes: notes,
            location: session.location,
            mood: mood
        )
        
        // Add to recent sessions
        recentSessions.append(session)
        if recentSessions.count > 50 {
            recentSessions = Array(recentSessions.suffix(50))
        }
        
        // Clear current session
        currentSession = nil
        currentCount = 0
        sessionTimer?.invalidate()
        
        // Update statistics
        await updateStatistics()
        
        do {
            try saveCachedData()
        } catch {
            self.error = error
        }
        
        // Completion feedback
        if currentCounter.hapticFeedback {
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)
        }
    }
    
    public func cancelSession() async {
        currentSession = nil
        currentCount = 0
        sessionTimer?.invalidate()
        
        // Remove from cache
        userDefaults.removeObject(forKey: CacheKeys.currentSession)
    }
    
    public func resetSession() async {
        guard var session = currentSession else { return }
        
        session = TasbihSession(
            id: session.id,
            dhikr: session.dhikr,
            startTime: Date(), // Reset start time
            endTime: session.endTime,
            currentCount: 0,
            targetCount: session.targetCount,
            isCompleted: session.isCompleted,
            isPaused: session.isPaused,
            totalDuration: 0,
            notes: session.notes,
            location: session.location,
            mood: session.mood
        )
        
        currentSession = session
        currentCount = 0
        
        do {
            try saveCachedData()
        } catch {
            self.error = error
        }
    }
    
    // MARK: - Counting Operations
    
    public func incrementCount(by increment: Int = 1, feedback: Bool = true) async {
        guard var session = currentSession, !session.isPaused else { return }
        
        let newCount = min(session.currentCount + increment, currentCounter.maxCount)
        currentCount = newCount
        
        session = TasbihSession(
            id: session.id,
            dhikr: session.dhikr,
            startTime: session.startTime,
            endTime: session.endTime,
            currentCount: newCount,
            targetCount: session.targetCount,
            isCompleted: newCount >= session.targetCount,
            isPaused: session.isPaused,
            totalDuration: session.totalDuration,
            notes: session.notes,
            location: session.location,
            mood: session.mood
        )
        
        currentSession = session
        
        // Provide feedback
        if feedback {
            await provideFeedback()
        }
        
        // Auto-complete if target reached
        if newCount >= session.targetCount && currentCounter.resetOnComplete {
            await completeSession()
        }
        
        do {
            try saveCachedData()
        } catch {
            self.error = error
        }
    }
    
    public func decrementCount(by decrement: Int = 1) async {
        guard var session = currentSession, !session.isPaused else { return }
        
        let newCount = max(session.currentCount - decrement, 0)
        currentCount = newCount
        
        session = TasbihSession(
            id: session.id,
            dhikr: session.dhikr,
            startTime: session.startTime,
            endTime: session.endTime,
            currentCount: newCount,
            targetCount: session.targetCount,
            isCompleted: false,
            isPaused: session.isPaused,
            totalDuration: session.totalDuration,
            notes: session.notes,
            location: session.location,
            mood: session.mood
        )
        
        currentSession = session
        
        do {
            try saveCachedData()
        } catch {
            self.error = error
        }
    }
    
    public func setCount(_ count: Int) async {
        guard var session = currentSession else { return }
        
        let newCount = max(0, min(count, currentCounter.maxCount))
        currentCount = newCount
        
        session = TasbihSession(
            id: session.id,
            dhikr: session.dhikr,
            startTime: session.startTime,
            endTime: session.endTime,
            currentCount: newCount,
            targetCount: session.targetCount,
            isCompleted: newCount >= session.targetCount,
            isPaused: session.isPaused,
            totalDuration: session.totalDuration,
            notes: session.notes,
            location: session.location,
            mood: session.mood
        )
        
        currentSession = session
        
        do {
            try saveCachedData()
        } catch {
            self.error = error
        }
    }

    public func updateTargetCount(_ target: Int) async {
        guard var session = currentSession else { return }

        let newTarget = max(1, min(target, currentCounter.maxCount))
        // Preserve current count - don't reduce it when target is lowered
        // Only clamp if count somehow exceeds the absolute maximum
        let newCount = min(session.currentCount, currentCounter.maxCount)
        currentCount = newCount

        session = TasbihSession(
            id: session.id,
            dhikr: session.dhikr,
            startTime: session.startTime,
            endTime: session.endTime,
            currentCount: newCount,
            targetCount: newTarget,
            isCompleted: newCount >= newTarget,
            isPaused: session.isPaused,
            totalDuration: session.totalDuration,
            notes: session.notes,
            location: session.location,
            mood: session.mood
        )

        currentSession = session

        do {
            try saveCachedData()
        } catch {
            self.error = error
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func startSessionTimer() {
        sessionTimer?.invalidate()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateSessionDuration()
            }
        }
    }
    
    private func updateSessionDuration() async {
        guard var session = currentSession, !session.isPaused else { return }
        
        let duration = Date().timeIntervalSince(session.startTime)
        
        session = TasbihSession(
            id: session.id,
            dhikr: session.dhikr,
            startTime: session.startTime,
            endTime: session.endTime,
            currentCount: session.currentCount,
            targetCount: session.targetCount,
            isCompleted: session.isCompleted,
            isPaused: session.isPaused,
            totalDuration: duration,
            notes: session.notes,
            location: session.location,
            mood: session.mood
        )
        
        currentSession = session
    }
    
    private func provideFeedback() async {
        // Haptic feedback
        if currentCounter.hapticFeedback {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
        
        // Sound feedback
        if currentCounter.soundFeedback, let soundName = currentCounter.soundName {
            playSound(named: soundName)
        }
    }
    
    private func playSound(named soundName: String) {
        guard let url = Bundle.main.url(forResource: soundName, withExtension: "mp3") else { return }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            // Handle audio error silently
        }
    }
    
    private func saveCachedData() throws {
        // Save dhikr
        let dhikrData = try JSONEncoder().encode(availableDhikr)
        userDefaults.set(dhikrData, forKey: CacheKeys.dhikrList)
        
        // Save sessions
        let sessionsData = try JSONEncoder().encode(recentSessions)
        userDefaults.set(sessionsData, forKey: CacheKeys.sessions)
        
        // Save current session
        if let session = currentSession {
            let sessionData = try JSONEncoder().encode(session)
            userDefaults.set(sessionData, forKey: CacheKeys.currentSession)
        } else {
            userDefaults.removeObject(forKey: CacheKeys.currentSession)
        }
        
        // Save counters
        let countersData = try JSONEncoder().encode(availableCounters)
        userDefaults.set(countersData, forKey: CacheKeys.counters)
        
        // Save statistics
        let statsData = try JSONEncoder().encode(statistics)
        userDefaults.set(statsData, forKey: CacheKeys.statistics)
    }
    
    private func updateStatistics() async {
        let totalSessions = recentSessions.count
        let completedSessions = recentSessions.filter { $0.isCompleted }.count
        let totalDhikrCount = recentSessions.reduce(0) { $0 + $1.currentCount }
        let totalDuration = recentSessions.reduce(0) { $0 + $1.totalDuration }
        let averageSessionDuration = totalSessions > 0 ? totalDuration / Double(totalSessions) : 0
        let longestSession = recentSessions.map { $0.totalDuration }.max() ?? 0
        
        // Calculate completion rate
        let completionRate = totalSessions > 0 ? Double(completedSessions) / Double(totalSessions) : 0
        
        // Calculate daily average
        let uniqueDays = Set(recentSessions.map { Calendar.current.startOfDay(for: $0.startTime) }).count
        let averageDailyCount = uniqueDays > 0 ? Double(totalDhikrCount) / Double(uniqueDays) : 0
        
        statistics = TasbihStatistics(
            totalSessions: totalSessions,
            completedSessions: completedSessions,
            totalDhikrCount: totalDhikrCount,
            totalDuration: totalDuration,
            averageSessionDuration: averageSessionDuration,
            longestSession: longestSession,
            currentStreak: calculateCurrentStreak(),
            longestStreak: calculateLongestStreak(),
            completionRate: completionRate,
            averageDailyCount: averageDailyCount
        )
    }
    
    private func calculateCurrentStreak() -> Int {
        // Simplified streak calculation
        let calendar = Calendar.current
        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())
        
        while true {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDate)!
            let dayHasSessions = recentSessions.contains { session in
                calendar.isDate(session.startTime, inSameDayAs: currentDate) && session.isCompleted
            }
            
            if !dayHasSessions {
                break
            }
            
            streak += 1
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
        }
        
        return streak
    }
    
    private func calculateLongestStreak() -> Int {
        // Simplified longest streak calculation
        return calculateCurrentStreak() // For now, return current streak
    }

    // MARK: - Dhikr Management

    public func getAllDhikr() async -> [Dhikr] {
        return availableDhikr
    }

    public func getDhikr(by category: DhikrCategory) async -> [Dhikr] {
        return availableDhikr.filter { $0.category == category }
    }

    public func addCustomDhikr(_ dhikr: Dhikr) async {
        var customDhikr = dhikr
        customDhikr = Dhikr(
            id: dhikr.id,
            arabicText: dhikr.arabicText,
            transliteration: dhikr.transliteration,
            translation: dhikr.translation,
            category: dhikr.category,
            reward: dhikr.reward,
            source: dhikr.source,
            isCustom: true,
            targetCount: dhikr.targetCount,
            createdAt: dhikr.createdAt
        )

        availableDhikr.append(customDhikr)

        do {
            try saveCachedData()
        } catch {
            self.error = error
        }
    }

    public func updateDhikr(_ dhikr: Dhikr) async {
        if let index = availableDhikr.firstIndex(where: { $0.id == dhikr.id }) {
            availableDhikr[index] = dhikr

            do {
                try saveCachedData()
            } catch {
                self.error = error
            }
        }
    }

    public func deleteDhikr(_ dhikrId: UUID) async {
        availableDhikr.removeAll { $0.id == dhikrId && $0.isCustom }

        do {
            try saveCachedData()
        } catch {
            self.error = error
        }
    }

    public func searchDhikr(_ query: String) async -> [Dhikr] {
        let lowercaseQuery = query.lowercased()
        return availableDhikr.filter { dhikr in
            dhikr.arabicText.lowercased().contains(lowercaseQuery) ||
            dhikr.transliteration.lowercased().contains(lowercaseQuery) ||
            dhikr.translation.lowercased().contains(lowercaseQuery)
        }
    }

    // MARK: - Session History

    public func getSessions(for period: DateInterval) async -> [TasbihSession] {
        return recentSessions.filter { session in
            period.contains(session.startTime)
        }
    }

    public func getSession(by sessionId: UUID) async -> TasbihSession? {
        return recentSessions.first { $0.id == sessionId }
    }

    public func deleteSession(_ sessionId: UUID) async {
        recentSessions.removeAll { $0.id == sessionId }

        do {
            try saveCachedData()
            await updateStatistics()
        } catch {
            self.error = error
        }
    }

    public func updateSessionNotes(_ sessionId: UUID, notes: String) async {
        if let index = recentSessions.firstIndex(where: { $0.id == sessionId }) {
            let session = recentSessions[index]
            recentSessions[index] = TasbihSession(
                id: session.id,
                dhikr: session.dhikr,
                startTime: session.startTime,
                endTime: session.endTime,
                currentCount: session.currentCount,
                targetCount: session.targetCount,
                isCompleted: session.isCompleted,
                isPaused: session.isPaused,
                totalDuration: session.totalDuration,
                notes: notes,
                location: session.location,
                mood: session.mood
            )

            do {
                try saveCachedData()
            } catch {
                self.error = error
            }
        }
    }

    // MARK: - Statistics

    public func getStatistics(for period: DateInterval) async -> TasbihStatistics {
        let periodSessions = await getSessions(for: period)

        let totalSessions = periodSessions.count
        let completedSessions = periodSessions.filter { $0.isCompleted }.count
        let totalDhikrCount = periodSessions.reduce(0) { $0 + $1.currentCount }
        let totalDuration = periodSessions.reduce(0) { $0 + $1.totalDuration }
        let averageSessionDuration = totalSessions > 0 ? totalDuration / Double(totalSessions) : 0
        let longestSession = periodSessions.map { $0.totalDuration }.max() ?? 0
        let completionRate = totalSessions > 0 ? Double(completedSessions) / Double(totalSessions) : 0

        let uniqueDays = Set(periodSessions.map { Calendar.current.startOfDay(for: $0.startTime) }).count
        let averageDailyCount = uniqueDays > 0 ? Double(totalDhikrCount) / Double(uniqueDays) : 0

        return TasbihStatistics(
            totalSessions: totalSessions,
            completedSessions: completedSessions,
            totalDhikrCount: totalDhikrCount,
            totalDuration: totalDuration,
            averageSessionDuration: averageSessionDuration,
            longestSession: longestSession,
            completionRate: completionRate,
            averageDailyCount: averageDailyCount
        )
    }

    public func getDailyCount(for date: Date) async -> Int {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!

        return recentSessions
            .filter { $0.startTime >= dayStart && $0.startTime < dayEnd }
            .reduce(0) { $0 + $1.currentCount }
    }

    public func getStreakInfo() async -> (current: Int, longest: Int) {
        return (current: calculateCurrentStreak(), longest: calculateLongestStreak())
    }

    // MARK: - Counter Management

    public func getAllCounters() async -> [TasbihCounter] {
        return availableCounters
    }

    public func addCounter(_ counter: TasbihCounter) async {
        availableCounters.append(counter)

        do {
            try saveCachedData()
        } catch {
            self.error = error
        }
    }

    public func updateCounter(_ counter: TasbihCounter) async {
        if let index = availableCounters.firstIndex(where: { $0.id == counter.id }) {
            availableCounters[index] = counter

            do {
                try saveCachedData()
            } catch {
                self.error = error
            }
        }
    }

    public func deleteCounter(_ counterId: UUID) async {
        availableCounters.removeAll { $0.id == counterId && !$0.isDefault }

        do {
            try saveCachedData()
        } catch {
            self.error = error
        }
    }

    public func setActiveCounter(_ counter: TasbihCounter) async {
        currentCounter = counter

        do {
            try saveCachedData()
        } catch {
            self.error = error
        }
    }

    // MARK: - Goals Management

    public func setGoal(_ goal: TasbihGoal) async {
        var goals = loadGoals()
        goals.append(goal)

        do {
            let data = try JSONEncoder().encode(goals)
            userDefaults.set(data, forKey: CacheKeys.goals)
        } catch {
            self.error = error
        }
    }

    public func getCurrentGoals() async -> [TasbihGoal] {
        let goals = loadGoals()
        return goals.filter { !$0.isCompleted && $0.targetDate >= Date() }
    }

    public func updateGoalProgress(_ goalId: UUID, progress: Int) async {
        var goals = loadGoals()

        if let index = goals.firstIndex(where: { $0.id == goalId }) {
            let goal = goals[index]
            goals[index] = TasbihGoal(
                id: goal.id,
                title: goal.title,
                description: goal.description,
                targetCount: goal.targetCount,
                currentCount: progress,
                targetDate: goal.targetDate,
                category: goal.category,
                specificDhikr: goal.specificDhikr,
                isCompleted: progress >= goal.targetCount,
                createdAt: goal.createdAt,
                completedAt: progress >= goal.targetCount ? Date() : nil,
                reward: goal.reward
            )

            do {
                let data = try JSONEncoder().encode(goals)
                userDefaults.set(data, forKey: CacheKeys.goals)
            } catch {
                self.error = error
            }
        }
    }

    public func completeGoal(_ goalId: UUID) async {
        await updateGoalProgress(goalId, progress: Int.max)
    }

    public func deleteGoal(_ goalId: UUID) async {
        var goals = loadGoals()
        goals.removeAll { $0.id == goalId }

        do {
            let data = try JSONEncoder().encode(goals)
            userDefaults.set(data, forKey: CacheKeys.goals)
        } catch {
            self.error = error
        }
    }

    // MARK: - Settings & Preferences

    public func setHapticFeedback(_ enabled: Bool) async {
        currentCounter = TasbihCounter(
            id: currentCounter.id,
            name: currentCounter.name,
            maxCount: currentCounter.maxCount,
            resetOnComplete: currentCounter.resetOnComplete,
            hapticFeedback: enabled,
            soundFeedback: currentCounter.soundFeedback,
            soundName: currentCounter.soundName,
            vibrationPattern: currentCounter.vibrationPattern,
            countIncrement: currentCounter.countIncrement,
            isDefault: currentCounter.isDefault,
            createdAt: currentCounter.createdAt
        )

        do {
            try saveCachedData()
        } catch {
            self.error = error
        }
    }

    public func setSoundFeedback(_ enabled: Bool) async {
        currentCounter = TasbihCounter(
            id: currentCounter.id,
            name: currentCounter.name,
            maxCount: currentCounter.maxCount,
            resetOnComplete: currentCounter.resetOnComplete,
            hapticFeedback: currentCounter.hapticFeedback,
            soundFeedback: enabled,
            soundName: currentCounter.soundName,
            vibrationPattern: currentCounter.vibrationPattern,
            countIncrement: currentCounter.countIncrement,
            isDefault: currentCounter.isDefault,
            createdAt: currentCounter.createdAt
        )

        do {
            try saveCachedData()
        } catch {
            self.error = error
        }
    }

    public func setVibrationPattern(_ pattern: VibrationPattern) async {
        currentCounter = TasbihCounter(
            id: currentCounter.id,
            name: currentCounter.name,
            maxCount: currentCounter.maxCount,
            resetOnComplete: currentCounter.resetOnComplete,
            hapticFeedback: currentCounter.hapticFeedback,
            soundFeedback: currentCounter.soundFeedback,
            soundName: currentCounter.soundName,
            vibrationPattern: pattern,
            countIncrement: currentCounter.countIncrement,
            isDefault: currentCounter.isDefault,
            createdAt: currentCounter.createdAt
        )

        do {
            try saveCachedData()
        } catch {
            self.error = error
        }
    }

    public func setDefaultTargetCount(_ count: Int) async {
        // This would typically be stored in user preferences
        // For now, we'll update the current counter's default behavior
    }

    // MARK: - Export & Import

    public func exportData(for period: DateInterval) async -> String {
        let sessions = await getSessions(for: period)

        let exportData: [String: Any] = [
            "sessions": sessions.map { session in
                [
                    "id": session.id.uuidString,
                    "dhikr": [
                        "arabicText": session.dhikr.arabicText,
                        "transliteration": session.dhikr.transliteration,
                        "translation": session.dhikr.translation,
                        "category": session.dhikr.category.rawValue
                    ],
                    "startTime": ISO8601DateFormatter().string(from: session.startTime),
                    "endTime": session.endTime.map { ISO8601DateFormatter().string(from: $0) },
                    "currentCount": session.currentCount,
                    "targetCount": session.targetCount,
                    "isCompleted": session.isCompleted,
                    "totalDuration": session.totalDuration,
                    "notes": session.notes,
                    "mood": session.mood?.rawValue
                ]
            },
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "period": [
                "start": ISO8601DateFormatter().string(from: period.start),
                "end": ISO8601DateFormatter().string(from: period.end)
            ]
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        } catch {
            return "{\"error\": \"Failed to export data\"}"
        }
    }

    public func exportStatistics(for period: DateInterval) async -> String {
        let stats = await getStatistics(for: period)

        var csv = "Metric,Value\n"
        csv += "Total Sessions,\(stats.totalSessions)\n"
        csv += "Completed Sessions,\(stats.completedSessions)\n"
        csv += "Total Dhikr Count,\(stats.totalDhikrCount)\n"
        csv += "Total Duration (seconds),\(stats.totalDuration)\n"
        csv += "Average Session Duration (seconds),\(stats.averageSessionDuration)\n"
        csv += "Longest Session (seconds),\(stats.longestSession)\n"
        csv += "Current Streak,\(stats.currentStreak)\n"
        csv += "Longest Streak,\(stats.longestStreak)\n"
        csv += "Completion Rate,\(stats.completionRate)\n"
        csv += "Average Daily Count,\(stats.averageDailyCount)\n"

        return csv
    }

    public func importDhikr(from jsonData: String) async throws {
        guard let data = jsonData.data(using: .utf8) else {
            throw NSError(domain: "TasbihService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON data"])
        }

        let dhikrArray = try JSONDecoder().decode([Dhikr].self, from: data)

        for dhikr in dhikrArray {
            await addCustomDhikr(dhikr)
        }
    }

    // MARK: - Cache Management

    public func clearCache() async {
        userDefaults.removeObject(forKey: CacheKeys.dhikrList)
        userDefaults.removeObject(forKey: CacheKeys.sessions)
        userDefaults.removeObject(forKey: CacheKeys.counters)
        userDefaults.removeObject(forKey: CacheKeys.goals)
        userDefaults.removeObject(forKey: CacheKeys.currentSession)
        userDefaults.removeObject(forKey: CacheKeys.settings)
        userDefaults.removeObject(forKey: CacheKeys.statistics)

        // Reset to defaults
        setupDefaultData()
        recentSessions = []
        currentSession = nil
        currentCount = 0
        statistics = TasbihStatistics()
    }

    public func refreshData() async {
        loadCachedData()
        await updateStatistics()
    }

    // MARK: - Private Helper Methods

    private func loadGoals() -> [TasbihGoal] {
        guard let data = userDefaults.data(forKey: CacheKeys.goals),
              let goals = try? JSONDecoder().decode([TasbihGoal].self, from: data) else {
            return []
        }
        return goals
    }
}
