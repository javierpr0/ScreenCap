import XCTest
@testable import ScreenCap

final class FloatingPreviewTests: XCTestCase {

    func testWindowSizeRespectMaxDimensions() {
        let largeImage = NSImage(size: NSSize(width: 2000, height: 1000))
        let window = FloatingPreviewWindow(image: largeImage)

        XCTAssertLessThanOrEqual(window.frame.width, 400, "Window width should not exceed max")
        XCTAssertLessThanOrEqual(window.frame.height, 300, "Window height should not exceed max")
    }

    func testWindowSizePreservesAspectRatio() {
        let image = NSImage(size: NSSize(width: 800, height: 400))
        let window = FloatingPreviewWindow(image: image)

        let originalRatio = 800.0 / 400.0
        let windowRatio = window.frame.width / window.frame.height
        XCTAssertEqual(originalRatio, windowRatio, accuracy: 0.01, "Aspect ratio should be preserved")
    }

    func testSmallImageUsesOriginalSize() {
        let smallImage = NSImage(size: NSSize(width: 100, height: 80))
        let window = FloatingPreviewWindow(image: smallImage)

        XCTAssertEqual(window.frame.width, 100, accuracy: 1)
        XCTAssertEqual(window.frame.height, 80, accuracy: 1)
    }

    func testWindowIsFloatingLevel() {
        let image = NSImage(size: NSSize(width: 200, height: 150))
        let window = FloatingPreviewWindow(image: image)

        XCTAssertEqual(window.level, .floating)
    }

    func testWindowIsBorderless() {
        let image = NSImage(size: NSSize(width: 200, height: 150))
        let window = FloatingPreviewWindow(image: image)

        XCTAssertTrue(window.styleMask.contains(.borderless))
    }

    func testPortraitImageSizing() {
        let image = NSImage(size: NSSize(width: 400, height: 800))
        let window = FloatingPreviewWindow(image: image)

        XCTAssertLessThanOrEqual(window.frame.height, 300)
        XCTAssertLessThan(window.frame.width, window.frame.height)
    }

    func testCustomAutoCloseTime() {
        let image = NSImage(size: NSSize(width: 200, height: 150))
        let window = FloatingPreviewWindow(image: image, autoCloseTime: 5.0)

        // Window should be created successfully
        XCTAssertNotNil(window)
    }

    func testZeroAutoCloseTimeNoTimer() {
        let image = NSImage(size: NSSize(width: 200, height: 150))
        let window = FloatingPreviewWindow(image: image, autoCloseTime: 0)

        // Window should be created successfully with no auto-close
        XCTAssertNotNil(window)
    }
}
