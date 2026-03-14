import AppKit
import Foundation
import Sentry

class FloatingPreviewWindow: NSWindow {
    // MARK: - Layout Constants

    private enum Layout {
        static let maxWidth: CGFloat = 400
        static let maxHeight: CGFloat = 300
        static let closeButtonSize: CGFloat = 20
        static let closeButtonPadding: CGFloat = 24
        static let cursorOffset: CGFloat = 20
        static let cornerRadius: CGFloat = 8
    }

    private enum Timing {
        static let fadeInDuration: TimeInterval = 0.3
        static let fadeOutDuration: TimeInterval = 0.2
        static let defaultAutoClose: TimeInterval = 10.0
    }

    // MARK: - Properties

    private var dragView: ImageDragView!
    private var autoCloseTimer: Timer?
    private var autoCloseTime: Double

    // MARK: - Initialization

    init(image: NSImage, autoCloseTime: Double = Timing.defaultAutoClose) {
        self.autoCloseTime = autoCloseTime

        let maxSize = CGSize(width: Layout.maxWidth, height: Layout.maxHeight)
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

        let contentRect = NSRect(origin: .zero, size: windowSize)

        super.init(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        setupWindow(with: image)
    }

    deinit {
        autoCloseTimer?.invalidate()
        autoCloseTimer = nil
    }

    // MARK: - Setup

    private func setupWindow(with image: NSImage) {
        self.isOpaque = false
        self.backgroundColor = NSColor.clear
        self.level = .floating
        self.isMovableByWindowBackground = true
        self.hasShadow = true
        self.isReleasedWhenClosed = true

        guard let contentView = self.contentView else {
            let error = NSError(domain: "ScreenCap", code: 102, userInfo: [NSLocalizedDescriptionKey: "contentView is nil in FloatingPreviewWindow"])
            SentrySDK.capture(error: error)
            return
        }

        dragView = ImageDragView(frame: contentView.bounds)
        dragView.image = image
        dragView.autoresizingMask = [.width, .height]
        contentView.addSubview(dragView)

        // Close button
        let closeButton = NSButton(title: "", target: self, action: #selector(closeButtonClicked))
        closeButton.bezelStyle = .circular
        closeButton.font = NSFont.systemFont(ofSize: 12)
        closeButton.frame = NSRect(
            x: self.frame.width - Layout.closeButtonPadding,
            y: self.frame.height - Layout.closeButtonPadding,
            width: Layout.closeButtonSize,
            height: Layout.closeButtonSize
        )
        closeButton.autoresizingMask = [.minXMargin, .minYMargin]
        closeButton.isBordered = false
        closeButton.title = "\u{2715}"
        closeButton.wantsLayer = true
        if let layer = closeButton.layer {
            layer.backgroundColor = NSColor.black.withAlphaComponent(0.5).cgColor
            layer.cornerRadius = Layout.closeButtonSize / 2
        }
        closeButton.contentTintColor = .white
        contentView.addSubview(closeButton)

        positionNearCursor()
        setupAutoClose()
        animateAppearance()
    }

    @objc func closeButtonClicked() {
        closeWithAnimation()
    }

    // MARK: - Positioning (checks all 4 edges)

    private func positionNearCursor() {
        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) ?? NSScreen.main else {
            return
        }

        let visibleFrame = screen.visibleFrame

        var origin = CGPoint(
            x: mouseLocation.x + Layout.cursorOffset,
            y: mouseLocation.y - frame.height - Layout.cursorOffset
        )

        // Right edge
        if origin.x + frame.width > visibleFrame.maxX {
            origin.x = mouseLocation.x - frame.width - Layout.cursorOffset
        }

        // Left edge
        if origin.x < visibleFrame.minX {
            origin.x = visibleFrame.minX
        }

        // Bottom edge
        if origin.y < visibleFrame.minY {
            origin.y = mouseLocation.y + Layout.cursorOffset
        }

        // Top edge
        if origin.y + frame.height > visibleFrame.maxY {
            origin.y = visibleFrame.maxY - frame.height
        }

        self.setFrameOrigin(origin)
    }

    // MARK: - Auto Close

    private func setupAutoClose() {
        guard autoCloseTime > 0 else { return }

        autoCloseTimer?.invalidate()
        autoCloseTimer = Timer.scheduledTimer(withTimeInterval: autoCloseTime, repeats: false) { [weak self] _ in
            self?.closeWithAnimation()
        }
    }

    // MARK: - Animations

    private func animateAppearance() {
        self.alphaValue = 0.0
        self.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Timing.fadeInDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1.0
        }
    }

    func closeWithAnimation() {
        autoCloseTimer?.invalidate()
        autoCloseTimer = nil

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Timing.fadeOutDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0.0
        }) { [weak self] in
            self?.releaseResources()
            self?.close()
        }
    }

    private func releaseResources() {
        dragView?.image = nil
    }

    // MARK: - Event Handling

    override func mouseDown(with event: NSEvent) {
        // Reset timer on explicit click interaction
        autoCloseTimer?.invalidate()
        setupAutoClose()
        super.mouseDown(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            closeWithAnimation()
        } else {
            super.keyDown(with: event)
        }
    }
}
