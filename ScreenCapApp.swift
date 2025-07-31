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

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var screenshotManager: ScreenshotManager?
    var settingsWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        SentrySDK.start { options in
            options.dsn = "https://8c7615afda19917d5fe98ace3ad57c60@o394654.ingest.us.sentry.io/4509668386930688"
            options.debug = true
        }
        // Configure the app to not appear in the dock
        NSApp.setActivationPolicy(.accessory)
        
        // Create the menu bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            if let image = NSImage(systemSymbolName: "camera.fill", accessibilityDescription: "ScreenCap") {
                button.image = image
            } else {
                // Fallback if the symbol is not available
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
        
        // Observe UserDefaults changes to update menu
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
        // Show menu on click
        statusItem?.menu?.popUp(positioning: nil, at: NSPoint.zero, in: statusItem?.button)
    }
    
    func setupMenu() {
        let menu = NSMenu()
        
        // Option for full screen capture
        let fullScreenItem = NSMenuItem(title: "Full Screen Capture", action: #selector(captureFullScreen), keyEquivalent: "")
        fullScreenItem.target = self
        if let image = NSImage(systemSymbolName: "rectangle.dashed", accessibilityDescription: nil) {
            fullScreenItem.image = image
        }
        menu.addItem(fullScreenItem)
        
        // Option for selection capture
        let selectionItem = NSMenuItem(title: "Selection Capture", action: #selector(captureSelection), keyEquivalent: "")
        selectionItem.target = self
        if let image = NSImage(systemSymbolName: "rectangle.dashed.and.paperclip", accessibilityDescription: nil) {
            selectionItem.image = image
        }
        menu.addItem(selectionItem)
        
        // Option for window capture
        let windowItem = NSMenuItem(title: "Window Capture", action: #selector(captureWindow), keyEquivalent: "")
        windowItem.target = self
        if let image = NSImage(systemSymbolName: "macwindow", accessibilityDescription: nil) {
            windowItem.image = image
        }
        menu.addItem(windowItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Settings
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        if let image = NSImage(systemSymbolName: "gear", accessibilityDescription: nil) {
            settingsItem.image = image
        }
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "")
        quitItem.target = self
        if let image = NSImage(systemSymbolName: "power", accessibilityDescription: nil) {
            quitItem.image = image
        }
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    @MainActor
    @objc func updateMenuShortcuts() {
        guard let menu = statusItem?.menu else { return }
        
        // Use a dictionary to safely map indices to shortcuts
        let shortcuts: [(index: Int, name: KeyboardShortcuts.Name)] = [
            (0, .captureFullScreen),
            (1, .captureSelection),
            (2, .captureWindow),
            (4, .openSettings),
            (6, .quitApp)
        ]
        
        for (index, shortcutName) in shortcuts {
            if index < menu.numberOfItems,
               let item = menu.item(at: index),
               let shortcut = KeyboardShortcuts.getShortcut(for: shortcutName) {
                item.keyEquivalent = shortcut.nsMenuItemKeyEquivalent ?? ""
                item.keyEquivalentModifierMask = shortcut.modifiers
            }
        }
    }
    
    
    @objc func captureFullScreen() {
        screenshotManager?.captureFullScreen()
    }
    
    @objc func captureSelection() {
        screenshotManager?.captureSelection()
    }
    
    @objc func captureWindow() {
        screenshotManager?.captureWindow()
    }
    
    @objc func openSettings() {
        // If a settings window already exists, just bring it to front
        if let existingWindow = settingsWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // Create new settings window
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
        
        // Configure delegate to clear reference when closed
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