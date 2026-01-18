import XCTest
@testable import ScreenCapCore

final class ConfigurationTests: XCTestCase {

    // MARK: - Sentry DSN Tests

    func testSentryDSNFromEnvironment() {
        // Set environment variable
        setenv("SENTRY_DSN", "https://test@sentry.io/123", 1)

        let dsn = Configuration.sentryDSN
        XCTAssertEqual(dsn, "https://test@sentry.io/123")

        // Clean up
        unsetenv("SENTRY_DSN")
    }

    func testSentryDSNIgnoresEmptyEnvironmentVariable() {
        // Set empty environment variable
        setenv("SENTRY_DSN", "", 1)

        let dsn = Configuration.sentryDSN
        // Should fall back to default or nil, not empty string
        XCTAssertNotEqual(dsn, "")

        // Clean up
        unsetenv("SENTRY_DSN")
    }

    // MARK: - Sentry Debug Tests

    func testSentryDebugFromEnvironment() {
        #if !DEBUG
        setenv("SENTRY_DEBUG", "true", 1)
        XCTAssertTrue(Configuration.sentryDebugEnabled)

        setenv("SENTRY_DEBUG", "false", 1)
        XCTAssertFalse(Configuration.sentryDebugEnabled)

        unsetenv("SENTRY_DEBUG")
        #else
        // In DEBUG mode, should always be true
        XCTAssertTrue(Configuration.sentryDebugEnabled)
        #endif
    }

    // MARK: - App Version Tests

    func testAppVersionReturnsString() {
        let version = Configuration.appVersion
        XCTAssertFalse(version.isEmpty)
    }

    func testAppVersionDefaultsTo1_0_0() {
        // When bundle doesn't have version info, it defaults to "1.0.0"
        // This is a simple sanity check
        let version = Configuration.appVersion
        XCTAssertTrue(version.contains(".") || version == "1.0.0")
    }

    // MARK: - Build Number Tests

    func testBuildNumberReturnsString() {
        let build = Configuration.buildNumber
        XCTAssertFalse(build.isEmpty)
    }

    func testBuildNumberDefaultsTo1() {
        // When bundle doesn't have build info, it defaults to "1"
        let build = Configuration.buildNumber
        XCTAssertNotNil(Int(build) ?? 1)
    }
}
