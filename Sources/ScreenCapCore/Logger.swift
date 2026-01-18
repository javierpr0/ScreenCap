import Foundation
import os.log

/// Centralized logging system for ScreenCap
/// Uses Apple's os.log for efficient, production-ready logging
public enum Logger {

    /// Log categories for different parts of the application
    public enum Category: String {
        case general = "General"
        case screenshot = "Screenshot"
        case permissions = "Permissions"
        case settings = "Settings"
        case ui = "UI"
        case shortcuts = "Shortcuts"
        case fileOperations = "FileOperations"
    }

    /// Log levels
    public enum Level {
        case debug
        case info
        case warning
        case error

        public var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            }
        }

        public var prefix: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            }
        }
    }

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.screencap"

    private static func logger(for category: Category) -> os.Logger {
        return os.Logger(subsystem: subsystem, category: category.rawValue)
    }

    /// Whether debug logging is enabled (only in DEBUG builds)
    #if DEBUG
    private static let isDebugEnabled = true
    #else
    private static let isDebugEnabled = false
    #endif

    // MARK: - Public Logging Methods

    /// Log a debug message (only in DEBUG builds)
    public static func debug(_ message: String, category: Category = .general) {
        guard isDebugEnabled else { return }
        logger(for: category).debug("\(Level.debug.prefix) \(message)")
    }

    /// Log an info message
    public static func info(_ message: String, category: Category = .general) {
        logger(for: category).info("\(Level.info.prefix) \(message)")
    }

    /// Log a warning message
    public static func warning(_ message: String, category: Category = .general) {
        logger(for: category).warning("\(Level.warning.prefix) \(message)")
    }

    /// Log an error message
    public static func error(_ message: String, category: Category = .general) {
        logger(for: category).error("\(Level.error.prefix) \(message)")
    }

    /// Log an error with an Error object
    public static func error(_ message: String, error: Error, category: Category = .general) {
        logger(for: category).error("\(Level.error.prefix) \(message): \(error.localizedDescription)")
    }
}
