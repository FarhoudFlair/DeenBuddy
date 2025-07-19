import Foundation
import os.log

/// Unified logging system for the DeenBuddy app with conditional compilation
public struct AppLogger {
    
    // MARK: - Log Categories
    
    public enum Category: String {
        case prayerTimes = "PrayerTimes"
        case qibla = "Qibla"
        case arCompass = "ARCompass"
        case notifications = "Notifications"
        case location = "Location"
        case cache = "Cache"
        case timer = "Timer"
        case background = "Background"
        case performance = "Performance"
        case ui = "UI"
        case general = "General"
        
        var subsystem: String {
            return "com.deenbuddy.app"
        }
    }
    
    // MARK: - Log Levels
    
    public enum Level {
        case debug
        case info
        case warning
        case error
        case critical
        
        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            case .critical: return .fault
            }
        }
        
        var emoji: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .critical: return "🚨"
            }
        }
    }
    
    // MARK: - Private Properties
    
    private let osLog: OSLog
    private let category: Category
    
    // MARK: - Initialization
    
    public init(category: Category) {
        self.category = category
        self.osLog = OSLog(subsystem: category.subsystem, category: category.rawValue)
    }
    
    // MARK: - Logging Methods
    
    /// Log a debug message (only in DEBUG builds)
    public func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        log(level: .debug, message: message, file: file, function: function, line: line)
        #endif
    }
    
    /// Log an info message
    public func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .info, message: message, file: file, function: function, line: line)
    }
    
    /// Log a warning message
    public func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .warning, message: message, file: file, function: function, line: line)
    }
    
    /// Log an error message
    public func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .error, message: message, file: file, function: function, line: line)
    }
    
    /// Log a critical message
    public func critical(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .critical, message: message, file: file, function: function, line: line)
    }
    
    // MARK: - Private Methods
    
    private func log(level: Level, message: String, file: String, function: String, line: Int) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "\(level.emoji) [\(fileName):\(line)] \(function) - \(message)"
        
        // Use unified logging system
        os_log("%{public}@", log: osLog, type: level.osLogType, logMessage)
        
        // Also print to console in DEBUG builds for immediate feedback
        #if DEBUG
        print(logMessage)
        #endif
    }
}

// MARK: - Convenience Extensions

public extension AppLogger {
    
    /// Create logger for prayer times
    static let prayerTimes = AppLogger(category: .prayerTimes)
    
    /// Create logger for Qibla compass
    static let qibla = AppLogger(category: .qibla)
    
    /// Create logger for AR compass
    static let arCompass = AppLogger(category: .arCompass)
    
    /// Create logger for notifications
    static let notifications = AppLogger(category: .notifications)
    
    /// Create logger for location services
    static let location = AppLogger(category: .location)
    
    /// Create logger for cache operations
    static let cache = AppLogger(category: .cache)
    
    /// Create logger for timer operations
    static let timer = AppLogger(category: .timer)
    
    /// Create logger for background operations
    static let background = AppLogger(category: .background)
    
    /// Create logger for performance monitoring
    static let performance = AppLogger(category: .performance)
    
    /// Create logger for UI operations
    static let ui = AppLogger(category: .ui)
    
    /// Create logger for general operations
    static let general = AppLogger(category: .general)
}

// MARK: - Legacy Print Replacement

/// Conditional print function that only outputs in DEBUG builds
public func debugPrint(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    #if DEBUG
    Swift.print(items, separator: separator, terminator: terminator)
    #endif
}