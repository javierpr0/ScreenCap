import SwiftUI
import AppKit
import Foundation
import KeyboardShortcuts
import Sentry
import UserNotifications

@main
struct ScreenCapApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

// MARK: - Menu Item Tags (replacing fragile index-based lookup)

private enum MenuTag: Int {
    case captureFullScreen = 100
    case captureSelection = 101
    case captureWindow = 102
    case openSettings = 200
    case quitApp = 300
    case copyToClipboard = 400
    case recentCapturesSubmenu = 500
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var screenshotManager: ScreenshotManager?
    var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        SentrySDK.start { options in
            options.dsn = "https://8c7615afda19917d5fe98ace3ad57c60@o394654.ingest.us.sentry.io/4509668386930688"
            options.debug = false
        }
        // Configure the app to not appear in the dock
        NSApp.setActivationPolicy(.accessory)

        // Create the menu bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            if let image = NSImage(systemSymbolName: "camera.fill", accessibilityDescription: "ScreenCap") {
                button.image = image
            } else {
                button.title = "SC"
            }
            button.action = #selector(statusBarButtonClicked)
            button.target = self
        }

        // Initialize the screenshot manager
        screenshotManager = ScreenshotManager()

        // Setup the menu
        setupMenu()

        // Setup global keyboard shortcuts
        setupGlobalHotkeys()

        // Update shortcuts initially
        updateMenuShortcuts()

        // Observe changes to update menu
        NotificationCenter.default.addObserver(self, selector: #selector(updateMenuShortcuts), name: UserDefaults.didChangeNotification, object: nil)
    }

    func setupGlobalHotkeys() {
        KeyboardShortcuts.onKeyUp(for: .captureFullScreen) { [weak self] in
            self?.captureFullScreen()
        }
        KeyboardShortcuts.onKeyUp(for: .captureSelection) { [weak self] in
            self?.captureSelection()
        }
        KeyboardShortcuts.onKeyUp(for: .captureWindow) { [weak self] in
            self?.captureWindow()
        }
        KeyboardShortcuts.onKeyUp(for: .openSettings) { [weak self] in
            self?.openSettings()
        }
        KeyboardShortcuts.onKeyUp(for: .quitApp) { [weak self] in
            self?.quit()
        }
    }

    @objc func statusBarButtonClicked() {
        // Rebuild recent captures before showing
        rebuildRecentCapturesSubmenu()
        statusItem?.menu?.popUp(positioning: nil, at: NSPoint.zero, in: statusItem?.button)
    }

    func setupMenu() {
        let menu = NSMenu()

        // Capture options
        let fullScreenItem = NSMenuItem(title: "Full Screen Capture", action: #selector(captureFullScreen), keyEquivalent: "")
        fullScreenItem.target = self
        fullScreenItem.tag = MenuTag.captureFullScreen.rawValue
        fullScreenItem.image = NSImage(systemSymbolName: "rectangle.dashed", accessibilityDescription: nil)
        menu.addItem(fullScreenItem)

        let selectionItem = NSMenuItem(title: "Selection Capture", action: #selector(captureSelection), keyEquivalent: "")
        selectionItem.target = self
        selectionItem.tag = MenuTag.captureSelection.rawValue
        selectionItem.image = NSImage(systemSymbolName: "rectangle.dashed.and.paperclip", accessibilityDescription: nil)
        menu.addItem(selectionItem)

        let windowItem = NSMenuItem(title: "Window Capture", action: #selector(captureWindow), keyEquivalent: "")
        windowItem.target = self
        windowItem.tag = MenuTag.captureWindow.rawValue
        windowItem.image = NSImage(systemSymbolName: "macwindow", accessibilityDescription: nil)
        menu.addItem(windowItem)

        menu.addItem(NSMenuItem.separator())

        // Copy to clipboard toggle
        let clipboardItem = NSMenuItem(title: "Copy to Clipboard", action: #selector(toggleCopyToClipboard), keyEquivalent: "")
        clipboardItem.target = self
        clipboardItem.tag = MenuTag.copyToClipboard.rawValue
        clipboardItem.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: nil)
        clipboardItem.state = (screenshotManager?.copyToClipboard ?? false) ? .on : .off
        menu.addItem(clipboardItem)

        menu.addItem(NSMenuItem.separator())

        // Recent captures submenu
        let recentItem = NSMenuItem(title: "Recent Captures", action: nil, keyEquivalent: "")
        recentItem.tag = MenuTag.recentCapturesSubmenu.rawValue
        recentItem.image = NSImage(systemSymbolName: "clock.arrow.circlepath", accessibilityDescription: nil)
        let recentSubmenu = NSMenu(title: "Recent Captures")
        recentItem.submenu = recentSubmenu
        menu.addItem(recentItem)

        menu.addItem(NSMenuItem.separator())

        // Settings
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        settingsItem.tag = MenuTag.openSettings.rawValue
        settingsItem.image = NSImage(systemSymbolName: "gear", accessibilityDescription: nil)
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "")
        quitItem.target = self
        quitItem.tag = MenuTag.quitApp.rawValue
        quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    // MARK: - Recent Captures Submenu

    private func rebuildRecentCapturesSubmenu() {
        guard let menu = statusItem?.menu,
              let recentItem = menu.item(withTag: MenuTag.recentCapturesSubmenu.rawValue),
              let submenu = recentItem.submenu else { return }

        submenu.removeAllItems()

        guard let captures = screenshotManager?.recentCaptures, !captures.isEmpty else {
            let emptyItem = NSMenuItem(title: "No recent captures", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            submenu.addItem(emptyItem)
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"

        for (index, capture) in captures.enumerated() {
            let timeStr = formatter.string(from: capture.timestamp)
            let title = "\(timeStr) — \(capture.filename)"
            let item = NSMenuItem(title: title, action: #selector(openRecentCapture(_:)), keyEquivalent: "")
            item.target = self
            item.tag = 1000 + index
            item.image = NSImage(systemSymbolName: "photo", accessibilityDescription: nil)
            submenu.addItem(item)
        }

        submenu.addItem(NSMenuItem.separator())

        // Open in Finder action for most recent
        let revealItem = NSMenuItem(title: "Show Last in Finder", action: #selector(revealLastCapture), keyEquivalent: "")
        revealItem.target = self
        revealItem.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
        submenu.addItem(revealItem)

        // Clear history
        let clearItem = NSMenuItem(title: "Clear History", action: #selector(clearRecentCaptures), keyEquivalent: "")
        clearItem.target = self
        clearItem.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)
        submenu.addItem(clearItem)
    }

    // MARK: - Menu Shortcut Sync (Tag-based)

    @MainActor
    @objc func updateMenuShortcuts() {
        guard let menu = statusItem?.menu else { return }

        let shortcuts: [(tag: Int, name: KeyboardShortcuts.Name)] = [
            (MenuTag.captureFullScreen.rawValue, .captureFullScreen),
            (MenuTag.captureSelection.rawValue, .captureSelection),
            (MenuTag.captureWindow.rawValue, .captureWindow),
            (MenuTag.openSettings.rawValue, .openSettings),
            (MenuTag.quitApp.rawValue, .quitApp)
        ]

        for (tag, shortcutName) in shortcuts {
            if let item = menu.item(withTag: tag),
               let shortcut = KeyboardShortcuts.getShortcut(for: shortcutName) {
                item.keyEquivalent = shortcut.nsMenuItemKeyEquivalent ?? ""
                item.keyEquivalentModifierMask = shortcut.modifiers
            }
        }

        // Update clipboard toggle state
        if let clipboardItem = menu.item(withTag: MenuTag.copyToClipboard.rawValue) {
            clipboardItem.state = (screenshotManager?.copyToClipboard ?? false) ? .on : .off
        }
    }

    // MARK: - Actions

    @objc func captureFullScreen() {
        screenshotManager?.captureFullScreen()
    }

    @objc func captureSelection() {
        screenshotManager?.captureSelection()
    }

    @objc func captureWindow() {
        screenshotManager?.captureWindow()
    }

    @MainActor
    @objc func toggleCopyToClipboard() {
        guard let manager = screenshotManager else { return }
        manager.updateCopyToClipboard(!manager.copyToClipboard)
        updateMenuShortcuts()
    }

    @objc func openRecentCapture(_ sender: NSMenuItem) {
        let index = sender.tag - 1000
        guard let captures = screenshotManager?.recentCaptures,
              index >= 0, index < captures.count else { return }
        screenshotManager?.openRecentCapture(captures[index])
    }

    @objc func revealLastCapture() {
        guard let capture = screenshotManager?.recentCaptures.first else { return }
        screenshotManager?.revealRecentCapture(capture)
    }

    @objc func clearRecentCaptures() {
        screenshotManager?.clearRecentCaptures()
    }

    @objc func openSettings() {
        if let existingWindow = settingsWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 520),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        guard let window = settingsWindow else { return }

        window.title = "ScreenCap Settings"
        window.contentView = NSHostingView(rootView: SettingsView())
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quit() {
        NSApp.terminate(nil)
    }
}

// MARK: - NSWindowDelegate
extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window == settingsWindow {
            settingsWindow = nil
        }
    }
}
