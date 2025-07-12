import Foundation
import Combine

/// Protocol for digital tasbih (dhikr counter) functionality
@MainActor
public protocol TasbihServiceProtocol: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current active tasbih session
    var currentSession: TasbihSession? { get }
    
    /// Current count in active session
    var currentCount: Int { get }
    
    /// Available dhikr options
    var availableDhikr: [Dhikr] { get }
    
    /// Recent tasbih sessions
    var recentSessions: [TasbihSession] { get }
    
    /// Tasbih statistics
    var statistics: TasbihStatistics { get }
    
    /// Loading state for tasbih operations
    var isLoading: Bool { get }
    
    /// Error state for tasbih operations
    var error: Error? { get }
    
    /// Current tasbih counter settings
    var currentCounter: TasbihCounter { get }
    
    /// Available counter configurations
    var availableCounters: [TasbihCounter] { get }
    
    // MARK: - Session Management
    
    /// Start a new tasbih session with specified dhikr
    /// - Parameters:
    ///   - dhikr: The dhikr to recite
    ///   - targetCount: Optional custom target count
    ///   - counter: Optional custom counter settings
    func startSession(with dhikr: Dhikr, targetCount: Int?, counter: TasbihCounter?) async
    
    /// Pause the current session
    func pauseSession() async
    
    /// Resume the paused session
    func resumeSession() async
    
    /// Complete the current session
    /// - Parameters:
    ///   - notes: Optional session notes
    ///   - mood: Optional session mood
    func completeSession(notes: String?, mood: SessionMood?) async
    
    /// Cancel the current session
    func cancelSession() async
    
    /// Reset current session count to zero
    func resetSession() async
    
    // MARK: - Counting Operations
    
    /// Increment the count in current session
    /// - Parameter increment: Number to increment by (default: 1)
    func incrementCount(by increment: Int) async
    
    /// Decrement the count in current session
    /// - Parameter decrement: Number to decrement by (default: 1)
    func decrementCount(by decrement: Int) async
    
    /// Set specific count in current session
    /// - Parameter count: The count to set
    func setCount(_ count: Int) async
    
    // MARK: - Dhikr Management
    
    /// Get all available dhikr
    /// - Returns: Array of dhikr
    func getAllDhikr() async -> [Dhikr]
    
    /// Get dhikr by category
    /// - Parameter category: The dhikr category
    /// - Returns: Array of dhikr in the category
    func getDhikr(by category: DhikrCategory) async -> [Dhikr]
    
    /// Add custom dhikr
    /// - Parameter dhikr: The custom dhikr to add
    func addCustomDhikr(_ dhikr: Dhikr) async
    
    /// Update existing dhikr
    /// - Parameter dhikr: The dhikr to update
    func updateDhikr(_ dhikr: Dhikr) async
    
    /// Delete dhikr (only custom dhikr can be deleted)
    /// - Parameter dhikrId: ID of the dhikr to delete
    func deleteDhikr(_ dhikrId: UUID) async
    
    /// Search dhikr by text
    /// - Parameter query: Search query
    /// - Returns: Array of matching dhikr
    func searchDhikr(_ query: String) async -> [Dhikr]
    
    // MARK: - Session History
    
    /// Get tasbih sessions for a date range
    /// - Parameter period: Date interval to query
    /// - Returns: Array of sessions in the period
    func getSessions(for period: DateInterval) async -> [TasbihSession]
    
    /// Get session by ID
    /// - Parameter sessionId: ID of the session
    /// - Returns: The session if found
    func getSession(by sessionId: UUID) async -> TasbihSession?
    
    /// Delete session
    /// - Parameter sessionId: ID of the session to delete
    func deleteSession(_ sessionId: UUID) async
    
    /// Update session notes
    /// - Parameters:
    ///   - sessionId: ID of the session
    ///   - notes: New notes
    func updateSessionNotes(_ sessionId: UUID, notes: String) async
    
    // MARK: - Statistics
    
    /// Get tasbih statistics for a period
    /// - Parameter period: Date interval to analyze
    /// - Returns: Statistics for the period
    func getStatistics(for period: DateInterval) async -> TasbihStatistics
    
    /// Get daily dhikr count for a date
    /// - Parameter date: The date to query
    /// - Returns: Total dhikr count for the date
    func getDailyCount(for date: Date) async -> Int
    
    /// Get streak information
    /// - Returns: Current and longest streak
    func getStreakInfo() async -> (current: Int, longest: Int)
    
    // MARK: - Counter Management
    
    /// Get all available counters
    /// - Returns: Array of tasbih counters
    func getAllCounters() async -> [TasbihCounter]
    
    /// Add custom counter
    /// - Parameter counter: The counter to add
    func addCounter(_ counter: TasbihCounter) async
    
    /// Update counter
    /// - Parameter counter: The counter to update
    func updateCounter(_ counter: TasbihCounter) async
    
    /// Delete counter (only custom counters can be deleted)
    /// - Parameter counterId: ID of the counter to delete
    func deleteCounter(_ counterId: UUID) async
    
    /// Set active counter
    /// - Parameter counter: The counter to set as active
    func setActiveCounter(_ counter: TasbihCounter) async
    
    // MARK: - Goals Management
    
    /// Set a tasbih goal
    /// - Parameter goal: The goal to set
    func setGoal(_ goal: TasbihGoal) async
    
    /// Get current active goals
    /// - Returns: Array of active goals
    func getCurrentGoals() async -> [TasbihGoal]
    
    /// Update goal progress
    /// - Parameters:
    ///   - goalId: ID of the goal
    ///   - progress: New progress count
    func updateGoalProgress(_ goalId: UUID, progress: Int) async
    
    /// Complete goal
    /// - Parameter goalId: ID of the goal to complete
    func completeGoal(_ goalId: UUID) async
    
    /// Delete goal
    /// - Parameter goalId: ID of the goal to delete
    func deleteGoal(_ goalId: UUID) async
    
    // MARK: - Settings & Preferences
    
    /// Enable/disable haptic feedback
    /// - Parameter enabled: Whether haptic feedback is enabled
    func setHapticFeedback(_ enabled: Bool) async
    
    /// Enable/disable sound feedback
    /// - Parameter enabled: Whether sound feedback is enabled
    func setSoundFeedback(_ enabled: Bool) async
    
    /// Set vibration pattern
    /// - Parameter pattern: The vibration pattern to use
    func setVibrationPattern(_ pattern: VibrationPattern) async
    
    /// Set default target count
    /// - Parameter count: The default target count
    func setDefaultTargetCount(_ count: Int) async
    
    // MARK: - Export & Import
    
    /// Export tasbih data as JSON
    /// - Parameter period: Date interval to export
    /// - Returns: JSON string of tasbih data
    func exportData(for period: DateInterval) async -> String
    
    /// Export statistics as CSV
    /// - Parameter period: Date interval to export
    /// - Returns: CSV string of statistics
    func exportStatistics(for period: DateInterval) async -> String
    
    /// Import dhikr from JSON
    /// - Parameter jsonData: JSON string containing dhikr data
    func importDhikr(from jsonData: String) async throws
    
    // MARK: - Cache Management
    
    /// Clear tasbih cache
    func clearCache() async
    
    /// Refresh data from storage
    func refreshData() async
}
