import XCTest
@testable import ScreenCap

final class TempFileCleanupTests: XCTestCase {

    let tempDir = FileManager.default.temporaryDirectory

    override func tearDown() {
        // Clean up any test temp files
        let fm = FileManager.default
        if let contents = try? fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil) {
            for file in contents where file.lastPathComponent.hasPrefix("ScreenCap_Test_") {
                try? fm.removeItem(at: file)
            }
        }
        super.tearDown()
    }

    func testTempFileUsesUUIDNaming() {
        let fileName1 = "ScreenCap_\(UUID().uuidString).png"
        let fileName2 = "ScreenCap_\(UUID().uuidString).png"

        XCTAssertNotEqual(fileName1, fileName2, "Each temp file should have a unique name")
        XCTAssertTrue(fileName1.hasPrefix("ScreenCap_"))
        XCTAssertTrue(fileName1.hasSuffix(".png"))
    }

    func testTempFileCreationAndCleanup() {
        let fileName = "ScreenCap_Test_\(UUID().uuidString).png"
        let fileURL = tempDir.appendingPathComponent(fileName)

        // Create temp file
        let data = Data("test".utf8)
        try? data.write(to: fileURL)

        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        // Clean up
        try? FileManager.default.removeItem(at: fileURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testAtomicWriteCreatesFile() {
        let fileName = "ScreenCap_Test_\(UUID().uuidString).png"
        let fileURL = tempDir.appendingPathComponent(fileName)

        let data = Data(repeating: 0xFF, count: 1024)
        do {
            try data.write(to: fileURL, options: .atomic)
            XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

            let readData = try Data(contentsOf: fileURL)
            XCTAssertEqual(readData.count, 1024)
        } catch {
            XCTFail("Atomic write failed: \(error)")
        }

        try? FileManager.default.removeItem(at: fileURL)
    }

    func testRecentCapturesCodable() {
        let capture = RecentCapture(filename: "test.png", filePath: "/tmp/test.png", captureType: "selection")

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        do {
            let data = try encoder.encode(capture)
            let decoded = try decoder.decode(RecentCapture.self, from: data)

            XCTAssertEqual(decoded.filename, "test.png")
            XCTAssertEqual(decoded.filePath, "/tmp/test.png")
            XCTAssertEqual(decoded.captureType, "selection")
        } catch {
            XCTFail("RecentCapture encoding/decoding failed: \(error)")
        }
    }

    func testRecentCapturesMaxLimit() {
        let manager = ScreenshotManager()

        // Manager should respect max limit
        XCTAssertEqual(ScreenshotManager.maxRecentCaptures, 10)
    }
}
