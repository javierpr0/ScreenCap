import XCTest
@testable import ScreenCap

final class DirectoryValidationTests: XCTestCase {

    var manager: ScreenshotManager!

    override func setUp() {
        super.setUp()
        manager = ScreenshotManager()
    }

    override func tearDown() {
        manager = nil
        super.tearDown()
    }

    func testValidateExistingWritableDirectory() {
        let tempDir = FileManager.default.temporaryDirectory
        let result = manager.validateSaveDirectory(tempDir)

        switch result {
        case .success:
            break // expected
        case .failure(let error):
            XCTFail("Expected success but got error: \(error)")
        }
    }

    func testValidateNonExistentDirectory() {
        let fakeDir = URL(fileURLWithPath: "/nonexistent/fake/path/\(UUID().uuidString)")
        let result = manager.validateSaveDirectory(fakeDir)

        switch result {
        case .success:
            XCTFail("Expected failure for non-existent directory")
        case .failure(let error):
            XCTAssertTrue(error.localizedDescription.contains("does not exist"))
        }
    }

    func testValidateFileInsteadOfDirectory() {
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("test_\(UUID().uuidString).txt")
        FileManager.default.createFile(atPath: tempFile.path, contents: Data("test".utf8))

        defer { try? FileManager.default.removeItem(at: tempFile) }

        let result = manager.validateSaveDirectory(tempFile)

        switch result {
        case .success:
            XCTFail("Expected failure for file path")
        case .failure:
            break // expected
        }
    }

    func testDefaultSaveDirectoryIsValid() {
        let defaultDir = manager.getCurrentSaveDirectory()
        let result = manager.validateSaveDirectory(defaultDir)

        switch result {
        case .success:
            break // expected
        case .failure(let error):
            XCTFail("Default save directory should be valid: \(error)")
        }
    }
}
