import Foundation

/// Application configuration management
/// Handles environment variables and configuration values
public enum Configuration {

    /// Sentry DSN for error tracking
    /// Reads from environment variable SENTRY_DSN first, falls back to bundled configuration
    public static var sentryDSN: String? {
        // First, try to get from environment variable
        if let envDSN = ProcessInfo.processInfo.environment["SENTRY_DSN"], !envDSN.isEmpty {
            return envDSN
        }

        // Fall back to bundled configuration file
        if let configPath = Bundle.main.path(forResource: "SentryConfig", ofType: "plist"),
           let config = NSDictionary(contentsOfFile: configPath),
           let dsn = config["DSN"] as? String, !dsn.isEmpty {
            return dsn
        }

        // Development fallback - in production this should come from environment or config file
        #if DEBUG
        return "https://8c7615afda19917d5fe98ace3ad57c60@o394654.ingest.us.sentry.io/4509668386930688"
        #else
        Logger.warning("Sentry DSN not configured. Error tracking will be disabled.", category: .general)
        return nil
        #endif
    }

    /// Whether Sentry debug mode is enabled
    public static var sentryDebugEnabled: Bool {
        #if DEBUG
        return true
        #else
        return ProcessInfo.processInfo.environment["SENTRY_DEBUG"] == "true"
        #endif
    }

    /// Application version from bundle
    public static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    /// Application build number from bundle
    public static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
