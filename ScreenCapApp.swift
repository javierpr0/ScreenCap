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
        // Configurar la app para que no aparezca en el dock
        NSApp.setActivationPolicy(.accessory)
        
        // Crear el item en la barra de menú
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            if let image = NSImage(systemSymbolName: "camera.fill", accessibilityDescription: "ScreenCap") {
                button.image = image
            } else {
                // Fallback si el símbolo no está disponible
                button.title = "SC"
            }
            button.action = #selector(statusBarButtonClicked)
            button.target = self
        }
        
        // Inicializar el manager de capturas
        screenshotManager = ScreenshotManager()
        
        // Configurar el menú
        setupMenu()
        
        // Configurar atajos de teclado globales
        setupGlobalHotkeys()
        
        // Actualizar shortcuts inicialmente
        updateMenuShortcuts()
        
        // Observar cambios en UserDefaults para actualizar menu
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
        // Mostrar menú al hacer clic
        statusItem?.menu?.popUp(positioning: nil, at: NSPoint.zero, in: statusItem?.button)
    }
    
    func setupMenu() {
        let menu = NSMenu()
        
        // Opción para captura de pantalla completa
        let fullScreenItem = NSMenuItem(title: "Captura Pantalla Completa", action: #selector(captureFullScreen), keyEquivalent: "")
        fullScreenItem.target = self
        if let image = NSImage(systemSymbolName: "rectangle.dashed", accessibilityDescription: nil) {
            fullScreenItem.image = image
        }
        menu.addItem(fullScreenItem)
        
        // Opción para captura de selección
        let selectionItem = NSMenuItem(title: "Captura de Selección", action: #selector(captureSelection), keyEquivalent: "")
        selectionItem.target = self
        if let image = NSImage(systemSymbolName: "rectangle.dashed.and.paperclip", accessibilityDescription: nil) {
            selectionItem.image = image
        }
        menu.addItem(selectionItem)
        
        // Opción para captura de ventana
        let windowItem = NSMenuItem(title: "Captura de Ventana", action: #selector(captureWindow), keyEquivalent: "")
        windowItem.target = self
        if let image = NSImage(systemSymbolName: "macwindow", accessibilityDescription: nil) {
            windowItem.image = image
        }
        menu.addItem(windowItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Configuración
        let settingsItem = NSMenuItem(title: "Configuración...", action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        if let image = NSImage(systemSymbolName: "gear", accessibilityDescription: nil) {
            settingsItem.image = image
        }
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Salir
        let quitItem = NSMenuItem(title: "Salir", action: #selector(quit), keyEquivalent: "")
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
        
        // Usar un diccionario para mapear índices a shortcuts de forma segura
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
        // Si ya existe una ventana de configuración, solo la traemos al frente
        if let existingWindow = settingsWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // Crear nueva ventana de configuración
        settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 520),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        guard let window = settingsWindow else { return }
        
        window.title = "Configuración ScreenCap"
        window.contentView = NSHostingView(rootView: SettingsView())
        window.center()
        window.isReleasedWhenClosed = false
        
        // Configurar delegate para limpiar la referencia cuando se cierre
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