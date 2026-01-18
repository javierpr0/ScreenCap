import XCTest
@testable import ScreenCapCore

final class LoggerTests: XCTestCase {

    // MARK: - Category Tests

    func testCategoryRawValues() {
        XCTAssertEqual(Logger.Category.general.rawValue, "General")
        XCTAssertEqual(Logger.Category.screenshot.rawValue, "Screenshot")
        XCTAssertEqual(Logger.Category.permissions.rawValue, "Permissions")
        XCTAssertEqual(Logger.Category.settings.rawValue, "Settings")
        XCTAssertEqual(Logger.Category.ui.rawValue, "UI")
        XCTAssertEqual(Logger.Category.shortcuts.rawValue, "Shortcuts")
        XCTAssertEqual(Logger.Category.fileOperations.rawValue, "FileOperations")
    }

    // MARK: - Level Tests

    func testLevelPrefixes() {
        XCTAssertEqual(Logger.Level.debug.prefix, "🔍")
        XCTAssertEqual(Logger.Level.info.prefix, "ℹ️")
        XCTAssertEqual(Logger.Level.warning.prefix, "⚠️")
        XCTAssertEqual(Logger.Level.error.prefix, "❌")
    }

    func testLevelOSLogTypes() {
        XCTAssertEqual(Logger.Level.debug.osLogType, .debug)
        XCTAssertEqual(Logger.Level.info.osLogType, .info)
        XCTAssertEqual(Logger.Level.warning.osLogType, .default)
        XCTAssertEqual(Logger.Level.error.osLogType, .error)
    }

    // MARK: - Logging Methods Tests
    // Note: These tests verify the methods can be called without crashing
    // Actual log output verification would require more complex testing infrastructure

    func testDebugLoggingDoesNotCrash() {
        Logger.debug("Test debug message")
        Logger.debug("Test debug message", category: .general)
        Logger.debug("Test debug message", category: .screenshot)
    }

    func testInfoLoggingDoesNotCrash() {
        Logger.info("Test info message")
        Logger.info("Test info message", category: .settings)
    }

    func testWarningLoggingDoesNotCrash() {
        Logger.warning("Test warning message")
        Logger.warning("Test warning message", category: .ui)
    }

    func testErrorLoggingDoesNotCrash() {
        Logger.error("Test error message")
        Logger.error("Test error message", category: .permissions)
    }

    func testErrorLoggingWithErrorObjectDoesNotCrash() {
        let testError = NSError(domain: "TestDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        Logger.error("Test error message", error: testError)
        Logger.error("Test error message", error: testError, category: .fileOperations)
    }

    // MARK: - All Categories Test

    func testLoggingWithAllCategoriesDoesNotCrash() {
        let categories: [Logger.Category] = [
            .general,
            .screenshot,
            .permissions,
            .settings,
            .ui,
            .shortcuts,
            .fileOperations
        ]

        for category in categories {
            Logger.debug("Debug test", category: category)
            Logger.info("Info test", category: category)
            Logger.warning("Warning test", category: category)
            Logger.error("Error test", category: category)
        }
    }

    // MARK: - Edge Cases

    func testLoggingEmptyMessage() {
        Logger.info("")
        Logger.warning("")
        Logger.error("")
    }

    func testLoggingLongMessage() {
        let longMessage = String(repeating: "a", count: 10000)
        Logger.info(longMessage)
    }

    func testLoggingSpecialCharacters() {
        Logger.info("Special chars: 日本語 🎉 émojis ñ")
        Logger.info("Newlines:\nLine1\nLine2")
        Logger.info("Tabs:\tColumn1\tColumn2")
    }
}
