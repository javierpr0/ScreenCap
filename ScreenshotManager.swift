import Foundation
import AppKit
import CoreGraphics
import UserNotifications
import AVFoundation
import Sentry
import ScreenCaptureKit

class ScreenshotManager: ObservableObject {
    private let userDefaults = UserDefaults.standard
    
    // Default configurations
    private var filePrefix: String {
        return userDefaults.string(forKey: "filePrefix") ?? "Screenshot"
    }
    
    private var saveDirectory: URL {
        if let savedPath = userDefaults.string(forKey: "saveDirectory"),
           let url = URL(string: savedPath) {
            return url
        }
        // Use a safe default value
        if let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first {
            return desktopURL
        }
        // Fallback to user's home directory
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
        // Configure default values if they don't exist
        setupDefaultSettings()
        // Request notification permissions
        requestNotificationPermission()
    }
    
    // MARK: - Permission Checking
    
    private func checkScreenRecordingPermission() -> Bool {
        // Since our target is macOS 14.0+, we can use ScreenCaptureKit directly
        return checkScreenCaptureKitPermission()
    }
    
    @available(macOS 14.0, *)
    private func checkScreenCaptureKitPermission() -> Bool {
        // Use ScreenCaptureKit to check if we can access screen content
        let semaphore = DispatchSemaphore(value: 0)
        var hasPermission = false
        
        Task {
            do {
                // Try to get shareable content - this requires screen recording permission
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                hasPermission = !content.displays.isEmpty
            } catch {
                hasPermission = false
            }
            semaphore.signal()
        }
        
        // Wait for async operation with timeout
        _ = semaphore.wait(timeout: .now() + 3.0)
        return hasPermission
    }
    
    
    private func showPermissionAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Screen Recording Permissions Required"
            alert.informativeText = "ScreenCap needs permissions to capture the screen.\n\n1. Go to System Settings > Privacy & Security\n2. Select 'Screen Recording'\n3. Turn on the switch for ScreenCap\n4. Restart the application"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // Open System Settings
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                    let opened = NSWorkspace.shared.open(url)
                    if !opened {
                        print("Could not open System Settings")
                        let error = NSError(domain: "ScreenCap", code: 100, userInfo: [NSLocalizedDescriptionKey: "Could not open System Settings"])
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
            showError("Could not access the main screen")
            return
        }
        
        let rect = screen.frame
        captureRect(rect, description: "full screen")
    }
    
    func captureSelection() {
        guard checkScreenRecordingPermission() else {
            showPermissionAlert()
            return
        }
        
        // Use macOS native command for selection
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        task.arguments = ["-i", "-s", "/tmp/screencap_temp.png"]
        
        task.terminationHandler = { _ in
            DispatchQueue.main.async {
                self.processTemporaryScreenshot(description: "selection")
            }
        }
        
        do {
            try task.run()
        } catch {
            showError("Error starting selection capture: \(error.localizedDescription)")
            SentrySDK.capture(error: error)
        }
    }
    
    func captureWindow() {
        guard checkScreenRecordingPermission() else {
            showPermissionAlert()
            return
        }
        
        // Use macOS native command for window
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        task.arguments = ["-i", "-w", "/tmp/screencap_temp.png"]
        
        task.terminationHandler = { _ in
            DispatchQueue.main.async {
                self.processTemporaryScreenshot(description: "window")
            }
        }
        
        do {
            try task.run()
        } catch {
            showError("Error starting window capture: \(error.localizedDescription)")
            SentrySDK.capture(error: error)
        }
    }
    
    private func captureRect(_ rect: NSRect, description: String) {
        // Since our target is macOS 14.0+, we can use ScreenCaptureKit directly
        captureRectWithScreenCaptureKit(rect, description: description)
    }
    
    @available(macOS 14.0, *)
    private func captureRectWithScreenCaptureKit(_ rect: NSRect, description: String) {
        Task {
            do {
                // Get available displays
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                
                guard let display = content.displays.first else {
                    await MainActor.run {
                        self.showError("No display found")
                    }
                    return
                }
                
                // Create content filter for the display
                let filter = SCContentFilter(display: display, excludingWindows: [])
                
                // Configure screenshot parameters
                let configuration = SCStreamConfiguration()
                configuration.width = Int(rect.width)
                configuration.height = Int(rect.height)
                configuration.sourceRect = rect
                configuration.showsCursor = true
                configuration.scalesToFit = false
                
                // Capture the screenshot
                let cgImage = try await SCScreenshotManager.captureImage(
                    contentFilter: filter,
                    configuration: configuration
                )
                
                // Convert to NSImage and save on main thread
                await MainActor.run {
                    let nsImage = NSImage(cgImage: cgImage, size: rect.size)
                    self.saveImage(nsImage, description: description)
                }
                
            } catch {
                await MainActor.run {
                    self.showError("ScreenCaptureKit error: \(error.localizedDescription)")
                    SentrySDK.capture(error: error)
                }
            }
        }
    }
    
    private func processTemporaryScreenshot(description: String) {
        let tempPath = "/tmp/screencap_temp.png"
        
        guard FileManager.default.fileExists(atPath: tempPath),
              let nsImage = NSImage(contentsOfFile: tempPath) else {
            // User cancelled the capture
            return
        }
        
        saveImage(nsImage, description: description)
        
        // Clean up temporary file
        do {
            try FileManager.default.removeItem(atPath: tempPath)
        } catch {
            // It's not critical if temporary file cleanup fails
            print("Could not delete temporary file: \(error)")
        }
    }
    
    private func saveImage(_ image: NSImage, description: String) {
        let filename = generateFilename()
        let fileURL = saveDirectory.appendingPathComponent(filename)
        
        guard let imageData = getImageData(from: image) else {
            showError("Could not process the image")
            return
        }
        
        do {
            try imageData.write(to: fileURL)
            showSuccess("\(description) capture saved: \(filename)")
            
            // Show floating window with captured image
            DispatchQueue.main.async {
                self.showFloatingPreview(image: image)
            }
        } catch {
            showError("Error saving: \(error.localizedDescription)")
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
            // If timestamp not included, add sequential number
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
                print("Error showing success notification: \(error)")
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
                print("Error showing error notification: \(error)")
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