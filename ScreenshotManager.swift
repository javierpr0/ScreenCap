import Foundation
import AppKit
import CoreGraphics
import UserNotifications
import AVFoundation
import Sentry

class ScreenshotManager: ObservableObject {
    private let userDefaults = UserDefaults.standard
    
    // Configuraciones por defecto
    private var filePrefix: String {
        return userDefaults.string(forKey: "filePrefix") ?? "Screenshot"
    }
    
    private var saveDirectory: URL {
        if let savedPath = userDefaults.string(forKey: "saveDirectory"),
           let url = URL(string: savedPath) {
            return url
        }
        // Usar un valor por defecto seguro
        if let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first {
            return desktopURL
        }
        // Fallback al directorio home del usuario
        return FileManager.default.homeDirectoryForCurrentUser
    }
    
    private var includeTimestamp: Bool {
        return userDefaults.bool(forKey: "includeTimestamp")
    }
    
    private var imageFormat: String {
        return userDefaults.string(forKey: "imageFormat") ?? "png"
    }
    
    private var floatingPreviewTime: Double {
        return userDefaults.double(forKey: "floatingPreviewTime") != 0 ? 
               userDefaults.double(forKey: "floatingPreviewTime") : 10.0
    }
    
    init() {
        // Configurar valores por defecto si no existen
        setupDefaultSettings()
        // Solicitar permisos de notificaciones
        requestNotificationPermission()
    }
    
    // MARK: - Permission Checking
    
    private func checkScreenRecordingPermission() -> Bool {
        if #available(macOS 10.15, *) {
            // En macOS 10.15+, verificar permisos de grabación de pantalla
            let runningApplication = NSRunningApplication.current
            _ = runningApplication.processIdentifier
            
            // Intentar crear una imagen de la pantalla para verificar permisos
            let image = CGWindowListCreateImage(
                CGRect(x: 0, y: 0, width: 1, height: 1),
                .optionOnScreenOnly,
                kCGNullWindowID,
                .bestResolution
            )
            
            return image != nil
        }
        return true // En versiones anteriores no se requieren permisos especiales
    }
    
    private func showPermissionAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Permisos de Grabación de Pantalla Requeridos"
            alert.informativeText = "ScreenCap necesita permisos para capturar la pantalla.\n\n1. Ve a Configuración del Sistema > Privacidad y Seguridad\n2. Selecciona 'Grabación de Pantalla'\n3. Activa el interruptor para ScreenCap\n4. Reinicia la aplicación"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Abrir Configuración")
            alert.addButton(withTitle: "Cancelar")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // Abrir Configuración del Sistema
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                    let opened = NSWorkspace.shared.open(url)
                    if !opened {
                        print("No se pudo abrir Configuración del Sistema")
                        let error = NSError(domain: "ScreenCap", code: 100, userInfo: [NSLocalizedDescriptionKey: "No se pudo abrir Configuración del Sistema"])
                        SentrySDK.capture(error: error)
                    }
                }
            }
        }
    }
    
    private func setupDefaultSettings() {
        if userDefaults.object(forKey: "filePrefix") == nil {
            userDefaults.set("Screenshot", forKey: "filePrefix")
        }
        if userDefaults.object(forKey: "includeTimestamp") == nil {
            userDefaults.set(false, forKey: "includeTimestamp")
        }
        if userDefaults.object(forKey: "imageFormat") == nil {
            userDefaults.set("png", forKey: "imageFormat")
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Error requesting notification permission: \(error)")
                SentrySDK.capture(error: error)
            }
        }
    }
    
    // MARK: - Capture Methods
    
    func captureFullScreen() {
        guard checkScreenRecordingPermission() else {
            showPermissionAlert()
            return
        }
        
        guard let screen = NSScreen.main else {
            showError("No se pudo acceder a la pantalla principal")
            return
        }
        
        let rect = screen.frame
        captureRect(rect, description: "pantalla completa")
    }
    
    func captureSelection() {
        guard checkScreenRecordingPermission() else {
            showPermissionAlert()
            return
        }
        
        // Usar el comando nativo de macOS para selección
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        task.arguments = ["-i", "-s", "/tmp/screencap_temp.png"]
        
        task.terminationHandler = { _ in
            DispatchQueue.main.async {
                self.processTemporaryScreenshot(description: "selección")
            }
        }
        
        do {
            try task.run()
        } catch {
            showError("Error al iniciar captura de selección: \(error.localizedDescription)")
            SentrySDK.capture(error: error)
        }
    }
    
    func captureWindow() {
        guard checkScreenRecordingPermission() else {
            showPermissionAlert()
            return
        }
        
        // Usar el comando nativo de macOS para ventana
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        task.arguments = ["-i", "-w", "/tmp/screencap_temp.png"]
        
        task.terminationHandler = { _ in
            DispatchQueue.main.async {
                self.processTemporaryScreenshot(description: "ventana")
            }
        }
        
        do {
            try task.run()
        } catch {
            showError("Error al iniciar captura de ventana: \(error.localizedDescription)")
            SentrySDK.capture(error: error)
        }
    }
    
    private func captureRect(_ rect: NSRect, description: String) {
        guard let cgImage = CGWindowListCreateImage(rect, .optionOnScreenOnly, kCGNullWindowID, .bestResolution) else {
            showError("No se pudo capturar la imagen")
            return
        }
        
        let nsImage = NSImage(cgImage: cgImage, size: rect.size)
        saveImage(nsImage, description: description)
    }
    
    private func processTemporaryScreenshot(description: String) {
        let tempPath = "/tmp/screencap_temp.png"
        
        guard FileManager.default.fileExists(atPath: tempPath),
              let nsImage = NSImage(contentsOfFile: tempPath) else {
            // El usuario canceló la captura
            return
        }
        
        saveImage(nsImage, description: description)
        
        // Limpiar archivo temporal
        do {
            try FileManager.default.removeItem(atPath: tempPath)
        } catch {
            // No es crítico si falla la limpieza del archivo temporal
            print("No se pudo eliminar archivo temporal: \(error)")
        }
    }
    
    private func saveImage(_ image: NSImage, description: String) {
        let filename = generateFilename()
        let fileURL = saveDirectory.appendingPathComponent(filename)
        
        guard let imageData = getImageData(from: image) else {
            showError("No se pudo procesar la imagen")
            return
        }
        
        do {
            try imageData.write(to: fileURL)
            showSuccess("Captura de \(description) guardada: \(filename)")
            
            // Mostrar ventana flotante con la imagen capturada
            DispatchQueue.main.async {
                self.showFloatingPreview(image: image)
            }
        } catch {
            showError("Error al guardar: \(error.localizedDescription)")
            SentrySDK.capture(error: error)
        }
    }
    
    private func showFloatingPreview(image: NSImage) {
        let previewWindow = FloatingPreviewWindow(image: image, autoCloseTime: floatingPreviewTime)
        previewWindow.makeKeyAndOrderFront(nil)
    }
    
    private func generateFilename() -> String {
        var filename = filePrefix
        
        if includeTimestamp {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            filename += "_\(formatter.string(from: Date()))"
        } else {
            // Si no incluye timestamp, agregar un número secuencial
            var counter = 1
            var testFilename: String
            repeat {
                testFilename = "\(filename)_\(counter).\(imageFormat)"
                counter += 1
            } while FileManager.default.fileExists(atPath: saveDirectory.appendingPathComponent(testFilename).path)
            
            return testFilename
        }
        
        return "\(filename).\(imageFormat)"
    }
    
    private func getImageData(from image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        
        switch imageFormat.lowercased() {
        case "png":
            return bitmapRep.representation(using: .png, properties: [:])
        case "jpg", "jpeg":
            return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
        default:
            return bitmapRep.representation(using: .png, properties: [:])
        }
    }
    
    // MARK: - Notifications
    
    private func showSuccess(_ message: String) {
        let content = UNMutableNotificationContent()
        content.title = "ScreenCap"
        content.body = message
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error al mostrar notificación de éxito: \(error)")
                SentrySDK.capture(error: error)
            }
        }
    }
    
    private func showError(_ message: String) {
        let content = UNMutableNotificationContent()
        content.title = "ScreenCap - Error"
        content.body = message
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error al mostrar notificación de error: \(error)")
                SentrySDK.capture(error: error)
            }
        }
    }
    
    // MARK: - Settings Management
    
    func updatePrefix(_ newPrefix: String) {
        userDefaults.set(newPrefix, forKey: "filePrefix")
    }
    
    func updateSaveDirectory(_ newDirectory: URL) {
        userDefaults.set(newDirectory.absoluteString, forKey: "saveDirectory")
    }
    
    func updateIncludeTimestamp(_ include: Bool) {
        userDefaults.set(include, forKey: "includeTimestamp")
    }
    
    func updateImageFormat(_ format: String) {
        userDefaults.set(format, forKey: "imageFormat")
    }
    
    func updateFloatingPreviewTime(_ time: Double) {
        userDefaults.set(time, forKey: "floatingPreviewTime")
    }
    
    // MARK: - Getters for Settings
    
    func getCurrentPrefix() -> String {
        return filePrefix
    }
    
    func getCurrentSaveDirectory() -> URL {
        return saveDirectory
    }
    
    func getCurrentIncludeTimestamp() -> Bool {
        return includeTimestamp
    }
    
    func getCurrentImageFormat() -> String {
        return imageFormat
    }
    
    func getCurrentFloatingPreviewTime() -> Double {
        return floatingPreviewTime
    }
}