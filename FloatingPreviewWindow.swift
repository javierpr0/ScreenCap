import AppKit
import Foundation
import Sentry

class FloatingPreviewWindow: NSWindow {
    private var dragView: ImageDragView!
    private var autoCloseTimer: Timer?
    private var autoCloseTime: Double
    
    init(image: NSImage, autoCloseTime: Double = 10.0) {
        self.autoCloseTime = autoCloseTime
        // Calculate window size based on the image
        let maxSize = CGSize(width: 400, height: 300)
        let imageSize = image.size
        let aspectRatio = imageSize.width / imageSize.height
        
        var windowSize: CGSize
        if imageSize.width > maxSize.width || imageSize.height > maxSize.height {
            if aspectRatio > 1 {
                windowSize = CGSize(width: maxSize.width, height: maxSize.width / aspectRatio)
            } else {
                windowSize = CGSize(width: maxSize.height * aspectRatio, height: maxSize.height)
            }
        } else {
            windowSize = imageSize
        }
        
        let contentRect = NSRect(
            x: 0,
            y: 0,
            width: windowSize.width,
            height: windowSize.height
        )
        
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        setupWindow(with: image)
    }
    
    private func setupWindow(with image: NSImage) {
        // Configure window properties
        self.isOpaque = false
        self.backgroundColor = NSColor.clear
        self.level = .floating
        self.isMovableByWindowBackground = true
        self.hasShadow = true
        self.isReleasedWhenClosed = false
        
        // Create custom drag view
        guard let contentView = self.contentView else {
            print("Error: contentView is nil")
            let error = NSError(domain: "ScreenCap", code: 102, userInfo: [NSLocalizedDescriptionKey: "contentView is nil in FloatingPreviewWindow"])
            SentrySDK.capture(error: error)
            return
        }
        
        dragView = ImageDragView(frame: contentView.bounds)
        dragView.image = image
        dragView.autoresizingMask = [.width, .height]
        
        contentView.addSubview(dragView)
        
        // Add close button
        let closeButton = NSButton(title: "✕", target: self, action: #selector(closeButtonClicked))
        closeButton.bezelStyle = .circular
        closeButton.font = NSFont.systemFont(ofSize: 12)
        closeButton.frame = NSRect(x: self.frame.width - 24, y: self.frame.height - 24, width: 20, height: 20)
        closeButton.autoresizingMask = [.minXMargin, .minYMargin]
        closeButton.isBordered = false
        closeButton.wantsLayer = true
        if let layer = closeButton.layer {
            layer.backgroundColor = NSColor.black.withAlphaComponent(0.5).cgColor
            layer.cornerRadius = 10
        }
        closeButton.contentTintColor = .white
        if let contentView = self.contentView {
            contentView.addSubview(closeButton)
        } else {
            print("Warning: contentView is nil when adding closeButton")
        }
        
        // Position window near cursor
        positionNearCursor()
        
        // Setup auto-close
        setupAutoClose()
        
        // Appearance animation
        animateAppearance()
    }
    
    @objc func closeButtonClicked() {
        closeWithAnimation()
    }
    
    private func positionNearCursor() {
        let mouseLocation = NSEvent.mouseLocation
        let screenFrame = NSScreen.main?.frame ?? NSRect.zero
        
        var windowOrigin = CGPoint(
            x: mouseLocation.x + 20,
            y: mouseLocation.y - frame.height - 20
        )
        
        // Ensure the window is within the screen bounds
        if windowOrigin.x + frame.width > screenFrame.maxX {
            windowOrigin.x = mouseLocation.x - frame.width - 20
        }
        
        if windowOrigin.y < screenFrame.minY {
            windowOrigin.y = mouseLocation.y + 20
        }
        
        self.setFrameOrigin(windowOrigin)
    }
    
    private func setupAutoClose() {
        // Only setup timer if time is greater than 0
        guard autoCloseTime > 0 else { return }
        
        autoCloseTimer = Timer.scheduledTimer(withTimeInterval: autoCloseTime, repeats: false) { [weak self] _ in
            self?.closeWithAnimation()
        }
    }
    
    private func animateAppearance() {
        self.alphaValue = 0.0
        self.makeKeyAndOrderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1.0
        }
    }
    
    func closeWithAnimation() {
        autoCloseTimer?.invalidate()
        autoCloseTimer = nil
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0.0
        }) {
            self.close()
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        // Reset timer on interaction
        autoCloseTimer?.invalidate()
        setupAutoClose()
        super.mouseDown(with: event)
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape key
            closeWithAnimation()
        } else {
            super.keyDown(with: event)
        }
    }
}