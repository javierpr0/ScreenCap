import AppKit
import Foundation
import Sentry

class ImageDragView: NSImageView {
    private var trackingArea: NSTrackingArea?
    private var isHovering = false
    private var currentTempFileURL: URL?

    private static let tempFilePrefix = "ScreenCap_"
    private static let staleTempFileAge: TimeInterval = 3600 // 1 hour

    override func awakeFromNib() {
        super.awakeFromNib()
        setupDragAndDrop()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupDragAndDrop()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupDragAndDrop()
    }

    deinit {
        cleanupCurrentTempFile()
    }

    // MARK: - Setup

    private func setupDragAndDrop() {
        self.imageScaling = .scaleProportionallyUpOrDown
        self.imageAlignment = .alignCenter
        self.wantsLayer = true
        self.layer?.cornerRadius = 8
        self.layer?.masksToBounds = true
        updateTrackingAreas()
    }

    // MARK: - Tracking Areas

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea = self.trackingArea {
            self.removeTrackingArea(trackingArea)
        }

        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeInKeyWindow]
        trackingArea = NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil)

        if let trackingArea = trackingArea {
            self.addTrackingArea(trackingArea)
        }
    }

    // MARK: - Hover Effects

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        isHovering = true
        updateAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isHovering = false
        updateAppearance()
    }

    private func updateAppearance() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            if isHovering {
                self.animator().alphaValue = 0.8
                self.layer?.borderWidth = 2
                self.layer?.borderColor = NSColor.controlAccentColor.cgColor
            } else {
                self.animator().alphaValue = 1.0
                self.layer?.borderWidth = 1
                self.layer?.borderColor = NSColor.separatorColor.cgColor
            }
        }
    }

    // MARK: - Drag Initiation

    override func mouseDown(with event: NSEvent) {
        guard let image = self.image else {
            super.mouseDown(with: event)
            return
        }

        // Clean up stale temp files from previous sessions
        cleanupStaleTempFiles()

        let pasteboardItem = NSPasteboardItem()

        if let tiffData = image.tiffRepresentation {
            pasteboardItem.setData(tiffData, forType: .tiff)
        }

        if let pngData = image.pngData {
            pasteboardItem.setData(pngData, forType: .png)
        }

        if let tempFileURL = createTemporaryImageFile(image: image) {
            currentTempFileURL = tempFileURL
            pasteboardItem.setString(tempFileURL.absoluteString, forType: .fileURL)
        }

        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)

        let dragImageSize = CGSize(width: 64, height: 64)
        let dragImage = createDragImage(from: image, size: dragImageSize)

        draggingItem.setDraggingFrame(
            NSRect(origin: .zero, size: dragImageSize),
            contents: dragImage
        )

        let draggingSession = beginDraggingSession(
            with: [draggingItem],
            event: event,
            source: self
        )

        draggingSession.animatesToStartingPositionsOnCancelOrFail = true
    }

    // MARK: - Drag Image

    private func createDragImage(from image: NSImage, size: CGSize) -> NSImage {
        let dragImage = NSImage(size: size)

        dragImage.lockFocus()
        NSColor.black.withAlphaComponent(0.1).setFill()
        NSRect(origin: .zero, size: size).fill()
        let imageRect = NSRect(origin: .zero, size: size).insetBy(dx: 4, dy: 4)
        image.draw(in: imageRect)
        dragImage.unlockFocus()

        return dragImage
    }

    // MARK: - Temp File Management

    private func createTemporaryImageFile(image: NSImage) -> URL? {
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileName = "\(Self.tempFilePrefix)\(UUID().uuidString).png"
        let tempFileURL = tempDirectory.appendingPathComponent(fileName)

        guard let pngData = image.pngData else {
            SentrySDK.capture(error: NSError(domain: "ScreenCap", code: 103, userInfo: [NSLocalizedDescriptionKey: "Failed to generate PNG data for drag"]))
            return nil
        }

        do {
            try pngData.write(to: tempFileURL, options: .atomic)
            return tempFileURL
        } catch {
            SentrySDK.capture(error: error)
            return nil
        }
    }

    private func cleanupCurrentTempFile() {
        guard let url = currentTempFileURL else { return }
        try? FileManager.default.removeItem(at: url)
        currentTempFileURL = nil
    }

    private func cleanupStaleTempFiles() {
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileManager = FileManager.default

        guard let contents = try? fileManager.contentsOfDirectory(
            at: tempDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else { return }

        let cutoff = Date().addingTimeInterval(-Self.staleTempFileAge)

        for fileURL in contents where fileURL.lastPathComponent.hasPrefix(Self.tempFilePrefix) {
            guard let attrs = try? fileURL.resourceValues(forKeys: [.creationDateKey]),
                  let created = attrs.creationDate,
                  created < cutoff else { continue }
            try? fileManager.removeItem(at: fileURL)
        }
    }
}

// MARK: - NSDraggingSource

extension ImageDragView: NSDraggingSource {
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .copy
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        // Clean up temp file after a delay (give receiving app time to read)
        let tempURL = currentTempFileURL
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if let url = tempURL {
                try? FileManager.default.removeItem(at: url)
            }
        }
        currentTempFileURL = nil

        if operation == .copy {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let window = self.window as? FloatingPreviewWindow {
                    window.closeWithAnimation()
                }
            }
        }
    }
}

// MARK: - NSImage Extension

extension NSImage {
    var pngData: Data? {
        guard let tiffData = self.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmapRep.representation(using: .png, properties: [:])
    }
}
