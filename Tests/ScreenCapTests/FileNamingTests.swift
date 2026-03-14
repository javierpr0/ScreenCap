import XCTest
@testable import ScreenCap

final class FileNamingTests: XCTestCase {

    // MARK: - Filename Sanitization

    func testSanitizeNormalFilename() {
        let result = ScreenshotManager.sanitizeFilename("MyScreenshot")
        XCTAssertEqual(result, "MyScreenshot")
    }

    func testSanitizeFilenameWithPathTraversal() {
        let result = ScreenshotManager.sanitizeFilename("../../etc/passwd")
        XCTAssertFalse(result.contains("/"))
        XCTAssertFalse(result.contains(".."))
    }

    func testSanitizeFilenameWithSlashes() {
        let result = ScreenshotManager.sanitizeFilename("my/file\\name")
        XCTAssertFalse(result.contains("/"))
        XCTAssertFalse(result.contains("\\"))
    }

    func testSanitizeFilenameWithSpecialChars() {
        let result = ScreenshotManager.sanitizeFilename("file:name*with?special<>chars")
        XCTAssertFalse(result.contains(":"))
        XCTAssertFalse(result.contains("*"))
        XCTAssertFalse(result.contains("?"))
        XCTAssertFalse(result.contains("<"))
        XCTAssertFalse(result.contains(">"))
    }

    func testSanitizeEmptyFilename() {
        let result = ScreenshotManager.sanitizeFilename("")
        XCTAssertEqual(result, "Screenshot")
    }

    func testSanitizeWhitespaceOnlyFilename() {
        let result = ScreenshotManager.sanitizeFilename("   ")
        XCTAssertEqual(result, "Screenshot")
    }

    func testSanitizeTruncatesLongFilename() {
        let longName = String(repeating: "a", count: 200)
        let result = ScreenshotManager.sanitizeFilename(longName)
        XCTAssertLessThanOrEqual(result.count, 100)
    }

    func testSanitizePreservesUnicode() {
        let result = ScreenshotManager.sanitizeFilename("Captura de pantalla")
        XCTAssertEqual(result, "Captura de pantalla")
    }

    func testSanitizeFilenameWithQuotes() {
        let result = ScreenshotManager.sanitizeFilename("file\"name")
        XCTAssertFalse(result.contains("\""))
    }

    // MARK: - Filename Generation

    func testGenerateFilenameProducesNonEmpty() {
        let manager = ScreenshotManager()
        let filename = manager.generateFilename()
        XCTAssertFalse(filename.isEmpty)
    }

    func testGenerateFilenameHasExtension() {
        let manager = ScreenshotManager()
        let filename = manager.generateFilename()
        XCTAssertTrue(
            filename.hasSuffix(".png") || filename.hasSuffix(".jpg") || filename.hasSuffix(".jpeg"),
            "Filename should have a valid image extension: \(filename)"
        )
    }
}
