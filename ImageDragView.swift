import AppKit
import Foundation
import Sentry

class ImageDragView: NSImageView {
    private var trackingArea: NSTrackingArea?
    private var isHovering = false
    
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
    
    private func setupDragAndDrop() {
        self.imageScaling = .scaleProportionallyUpOrDown
        self.imageAlignment = .alignCenter
        self.wantsLayer = true
        self.layer?.cornerRadius = 8
        self.layer?.masksToBounds = true
        
        // Configure tracking area for hover effects
        updateTrackingAreas()
    }
    
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
    
    override func mouseDown(with event: NSEvent) {
        guard let image = self.image else {
            super.mouseDown(with: event)
            return
        }
        
        // Prepare data for dragging
        let pasteboardItem = NSPasteboardItem()
        
        // Add image as TIFF
        if let tiffData = image.tiffRepresentation {
            pasteboardItem.setData(tiffData, forType: .tiff)
        }
        
        // Add image as PNG
        if let pngData = image.pngData {
            pasteboardItem.setData(pngData, forType: .png)
        }
        
        // Create temporary file for dragging to folders
        if let tempFileURL = createTemporaryImageFile(image: image) {
            pasteboardItem.setString(tempFileURL.absoluteString, forType: .fileURL)
        }
        
        // Create dragging session
        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
        
        // Configure drag image
        let dragImageSize = CGSize(width: 64, height: 64)
        let dragImage = createDragImage(from: image, size: dragImageSize)
        
        draggingItem.setDraggingFrame(
            NSRect(origin: .zero, size: dragImageSize),
            contents: dragImage
        )
        
        // Start dragging session
        let draggingSession = beginDraggingSession(
            with: [draggingItem],
            event: event,
            source: self
        )
        
        draggingSession.animatesToStartingPositionsOnCancelOrFail = true
    }
    
    private func createDragImage(from image: NSImage, size: CGSize) -> NSImage {
        let dragImage = NSImage(size: size)
        
        dragImage.lockFocus()
        
        // Draw semi-transparent background
        NSColor.black.withAlphaComponent(0.1).setFill()
        NSRect(origin: .zero, size: size).fill()
        
        // Draw scaled image
        let imageRect = NSRect(origin: .zero, size: size).insetBy(dx: 4, dy: 4)
        image.draw(in: imageRect)
        
        dragImage.unlockFocus()
        
        return dragImage
    }
    
    private func createTemporaryImageFile(image: NSImage) -> URL? {
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileName = "ScreenCap_\(Date().timeIntervalSince1970).png"
        let tempFileURL = tempDirectory.appendingPathComponent(fileName)
        
        guard let pngData = image.pngData else {
            return nil
        }
        
        do {
            try pngData.write(to: tempFileURL)
            return tempFileURL
        } catch {
            print("Error creating temporary file: \(error)")
            SentrySDK.capture(error: error)
            return nil
        }
    }
}

// MARK: - NSDraggingSource
extension ImageDragView: NSDraggingSource {
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .copy
    }
    
    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        if operation == .copy {
            // Close floating window after successful drag
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