import XCTest
@testable import ScreenCapCore

final class FilePrefixValidatorTests: XCTestCase {

    // MARK: - Sanitize Tests

    func testSanitizeRemovesInvalidCharacters() {
        XCTAssertEqual(FilePrefixValidator.sanitize("test/file"), "testfile")
        XCTAssertEqual(FilePrefixValidator.sanitize("test\\file"), "testfile")
        XCTAssertEqual(FilePrefixValidator.sanitize("test:file"), "testfile")
        XCTAssertEqual(FilePrefixValidator.sanitize("test*file"), "testfile")
        XCTAssertEqual(FilePrefixValidator.sanitize("test?file"), "testfile")
        XCTAssertEqual(FilePrefixValidator.sanitize("test\"file"), "testfile")
        XCTAssertEqual(FilePrefixValidator.sanitize("test<file"), "testfile")
        XCTAssertEqual(FilePrefixValidator.sanitize("test>file"), "testfile")
        XCTAssertEqual(FilePrefixValidator.sanitize("test|file"), "testfile")
    }

    func testSanitizeRemovesMultipleInvalidCharacters() {
        XCTAssertEqual(FilePrefixValidator.sanitize("te/st:fi*le"), "testfile")
        XCTAssertEqual(FilePrefixValidator.sanitize("/\\:*?\"<>|"), "Screenshot")
    }

    func testSanitizeTrimsWhitespace() {
        XCTAssertEqual(FilePrefixValidator.sanitize("  test  "), "test")
        XCTAssertEqual(FilePrefixValidator.sanitize("\ttest\t"), "test")
    }

    func testSanitizeReplacesMultipleSpaces() {
        XCTAssertEqual(FilePrefixValidator.sanitize("test  file"), "test file")
        XCTAssertEqual(FilePrefixValidator.sanitize("test   file"), "test file")
        XCTAssertEqual(FilePrefixValidator.sanitize("test    file"), "test file")
    }

    func testSanitizeLimitsLength() {
        let longPrefix = String(repeating: "a", count: 100)
        let result = FilePrefixValidator.sanitize(longPrefix)
        XCTAssertEqual(result.count, FilePrefixValidator.maxPrefixLength)
    }

    func testSanitizeReturnsDefaultForEmptyString() {
        XCTAssertEqual(FilePrefixValidator.sanitize(""), FilePrefixValidator.defaultPrefix)
    }

    func testSanitizeReturnsDefaultForOnlyInvalidCharacters() {
        XCTAssertEqual(FilePrefixValidator.sanitize("/\\:*?"), FilePrefixValidator.defaultPrefix)
    }

    func testSanitizePreservesValidCharacters() {
        XCTAssertEqual(FilePrefixValidator.sanitize("Screenshot"), "Screenshot")
        XCTAssertEqual(FilePrefixValidator.sanitize("My-Screenshot_2024"), "My-Screenshot_2024")
        XCTAssertEqual(FilePrefixValidator.sanitize("Test.File.Name"), "Test.File.Name")
    }

    // MARK: - Validation Tests

    func testIsValidReturnsFalseForEmptyString() {
        XCTAssertFalse(FilePrefixValidator.isValid(""))
    }

    func testIsValidReturnsFalseForTooLongString() {
        let longPrefix = String(repeating: "a", count: 51)
        XCTAssertFalse(FilePrefixValidator.isValid(longPrefix))
    }

    func testIsValidReturnsFalseForInvalidCharacters() {
        XCTAssertFalse(FilePrefixValidator.isValid("test/file"))
        XCTAssertFalse(FilePrefixValidator.isValid("test\\file"))
        XCTAssertFalse(FilePrefixValidator.isValid("test:file"))
        XCTAssertFalse(FilePrefixValidator.isValid("test*file"))
        XCTAssertFalse(FilePrefixValidator.isValid("test?file"))
        XCTAssertFalse(FilePrefixValidator.isValid("test\"file"))
        XCTAssertFalse(FilePrefixValidator.isValid("test<file"))
        XCTAssertFalse(FilePrefixValidator.isValid("test>file"))
        XCTAssertFalse(FilePrefixValidator.isValid("test|file"))
    }

    func testIsValidReturnsFalseForLeadingWhitespace() {
        XCTAssertFalse(FilePrefixValidator.isValid(" test"))
    }

    func testIsValidReturnsFalseForTrailingWhitespace() {
        XCTAssertFalse(FilePrefixValidator.isValid("test "))
    }

    func testIsValidReturnsFalseForMultipleSpaces() {
        XCTAssertFalse(FilePrefixValidator.isValid("test  file"))
    }

    func testIsValidReturnsTrueForValidPrefix() {
        XCTAssertTrue(FilePrefixValidator.isValid("Screenshot"))
        XCTAssertTrue(FilePrefixValidator.isValid("My-Screenshot"))
        XCTAssertTrue(FilePrefixValidator.isValid("Screenshot_2024"))
        XCTAssertTrue(FilePrefixValidator.isValid("Test File"))
        XCTAssertTrue(FilePrefixValidator.isValid("a"))
    }

    func testIsValidReturnsTrueForMaxLength() {
        let maxLengthPrefix = String(repeating: "a", count: FilePrefixValidator.maxPrefixLength)
        XCTAssertTrue(FilePrefixValidator.isValid(maxLengthPrefix))
    }

    // MARK: - Validation Errors Tests

    func testValidationErrorsForEmptyString() {
        let errors = FilePrefixValidator.validationErrors(for: "")
        XCTAssertTrue(errors.contains { $0.contains("empty") })
    }

    func testValidationErrorsForTooLongString() {
        let longPrefix = String(repeating: "a", count: 51)
        let errors = FilePrefixValidator.validationErrors(for: longPrefix)
        XCTAssertTrue(errors.contains { $0.contains("maximum length") })
    }

    func testValidationErrorsForInvalidCharacters() {
        let errors = FilePrefixValidator.validationErrors(for: "test/file")
        XCTAssertTrue(errors.contains { $0.contains("invalid characters") })
    }

    func testValidationErrorsForLeadingWhitespace() {
        let errors = FilePrefixValidator.validationErrors(for: " test")
        XCTAssertTrue(errors.contains { $0.contains("whitespace") })
    }

    func testValidationErrorsForMultipleSpaces() {
        let errors = FilePrefixValidator.validationErrors(for: "test  file")
        XCTAssertTrue(errors.contains { $0.contains("consecutive spaces") })
    }

    func testValidationErrorsReturnsEmptyForValidPrefix() {
        let errors = FilePrefixValidator.validationErrors(for: "Screenshot")
        XCTAssertTrue(errors.isEmpty)
    }

    func testValidationErrorsReturnsMultipleErrorsForMultipleIssues() {
        let errors = FilePrefixValidator.validationErrors(for: " test/file  ")
        XCTAssertGreaterThan(errors.count, 1)
    }

    // MARK: - Constants Tests

    func testDefaultPrefixValue() {
        XCTAssertEqual(FilePrefixValidator.defaultPrefix, "Screenshot")
    }

    func testMaxPrefixLengthValue() {
        XCTAssertEqual(FilePrefixValidator.maxPrefixLength, 50)
    }

    func testInvalidCharactersSet() {
        let invalidChars = "/:\\*?\"<>|"
        for char in invalidChars {
            XCTAssertTrue(FilePrefixValidator.invalidFileNameCharacters.contains(char.unicodeScalars.first!))
        }
    }
}
