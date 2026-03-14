import Foundation
import AppKit
import CoreGraphics
import UserNotifications
import AVFoundation
import Sentry
import ScreenCaptureKit

// MARK: - Custom Error Types

enum ScreenCapError: LocalizedError {
    case noDisplayFound
    case permissionDenied
    case captureKitError(String)
    case fileWriteError(String)
    case imageProcessingError
    case invalidSaveDirectory(String)

    var errorDescription: String? {
        switch self {
        case .noDisplayFound: return "No display found"
        case .permissionDenied: return "Screen recording permission denied"
        case .captureKitError(let msg): return "ScreenCaptureKit error: \(msg)"
        case .fileWriteError(let msg): return "Error saving: \(msg)"
        case .imageProcessingError: return "Could not process the image"
        case .invalidSaveDirectory(let msg): return "Invalid save directory: \(msg)"
        }
    }
}

// MARK: - Recent Capture Model

struct RecentCapture: Identifiable, Codable {
    let id: UUID
    let filename: String
    let filePath: String
    let captureType: String
    let timestamp: Date

    init(filename: String, filePath: String, captureType: String) {
        self.id = UUID()
        self.filename = filename
        self.filePath = filePath
        self.captureType = captureType
        self.timestamp = Date()
    }
}

// MARK: - Screenshot Manager

class ScreenshotManager: ObservableObject {
    private let userDefaults = UserDefaults.standard

    static let maxRecentCaptures = 10

    // MARK: - Published State

    @Published var recentCaptures: [RecentCapture] = []
    @Published var copyToClipboard: Bool = false

    // MARK: - Configuration Properties

    private var filePrefix: String {
        let raw = userDefaults.string(forKey: "filePrefix") ?? "Screenshot"
        return Self.sanitizeFilename(raw)
    }

    private var saveDirectory: URL {
        if let savedPath = userDefaults.string(forKey: "saveDirectory"),
           let url = URL(string: savedPath) {
            return url
        }
        if let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first {
            return desktopURL
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    private var includeTimestamp: Bool {
        return userDefaults.bool(forKey: "includeTimestamp")
    }

    private var imageFormat: String {
        return userDefaults.string(forKey: "imageFormat") ?? "png"
    }

    private var floatingPreviewTime: Double {
        let time = userDefaults.double(forKey: "floatingPreviewTime")
        return time > 0 ? time : 10.0
    }

    // MARK: - Initialization

    init() {
        setupDefaultSettings()
        requestNotificationPermission()
        loadRecentCaptures()
        copyToClipboard = userDefaults.bool(forKey: "copyToClipboard")
    }

    // MARK: - Filename Sanitization

    static func sanitizeFilename(_ input: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\:*?\"<>|.")
        let sanitized = input.components(separatedBy: forbidden).joined(separator: "_")
        let trimmed = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Screenshot" : String(trimmed.prefix(100))
    }

    // MARK: - Directory Validation

    func validateSaveDirectory(_ url: URL) -> Result<Void, ScreenCapError> {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return .failure(.invalidSaveDirectory("Directory does not exist"))
        }
        guard FileManager.default.isWritableFile(atPath: url.path) else {
            return .failure(.invalidSaveDirectory("Directory is not writable"))
        }
        return .success(())
    }

    // MARK: - Permission Checking (Async)

    private func checkScreenRecordingPermissionAsync() async -> Bool {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            return !content.displays.isEmpty
        } catch {
            return false
        }
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

    private func checkNotificationPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus == .authorized)
            }
        }
    }

    // MARK: - Capture Methods (Now Async)

    func captureFullScreen() {
        Task {
            guard await checkScreenRecordingPermissionAsync() else {
                await MainActor.run { showPermissionAlert() }
                return
            }
            await performFullScreenCapture()
        }
    }

    @MainActor
    private func performFullScreenCapture() async {
        guard let screen = NSScreen.main else {
            showError("Could not access the main screen")
            return
        }
        let rect = screen.frame
        await captureRectWithScreenCaptureKit(rect, description: "full screen")
    }

    func captureSelection() {
        Task {
            guard await checkScreenRecordingPermissionAsync() else {
                await MainActor.run { showPermissionAlert() }
                return
            }
            await performSelectionCapture()
        }
    }

    private func performSelectionCapture() async {
        let tempPath = "/tmp/screencap_\(UUID().uuidString).png"

        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        task.arguments = ["-i", "-s", tempPath]

        do {
            try task.run()
            task.waitUntilExit()
            await MainActor.run {
                self.processTemporaryScreenshot(at: tempPath, description: "selection")
            }
        } catch {
            await MainActor.run {
                self.showError("Error starting selection capture: \(error.localizedDescription)")
                SentrySDK.capture(error: error)
            }
        }
    }

    func captureWindow() {
        Task {
            guard await checkScreenRecordingPermissionAsync() else {
                await MainActor.run { showPermissionAlert() }
                return
            }
            await performWindowCapture()
        }
    }

    private func performWindowCapture() async {
        let tempPath = "/tmp/screencap_\(UUID().uuidString).png"

        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        task.arguments = ["-i", "-w", tempPath]

        do {
            try task.run()
            task.waitUntilExit()
            await MainActor.run {
                self.processTemporaryScreenshot(at: tempPath, description: "window")
            }
        } catch {
            await MainActor.run {
                self.showError("Error starting window capture: \(error.localizedDescription)")
                SentrySDK.capture(error: error)
            }
        }
    }

    // MARK: - Multi-Monitor Support

    func captureDisplay(at index: Int) {
        Task {
            guard await checkScreenRecordingPermissionAsync() else {
                await MainActor.run { showPermissionAlert() }
                return
            }

            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard index < content.displays.count else {
                    await MainActor.run { self.showError("Display not found") }
                    return
                }

                let display = content.displays[index]
                let filter = SCContentFilter(display: display, excludingWindows: [])

                let configuration = SCStreamConfiguration()
                configuration.width = display.width
                configuration.height = display.height
                configuration.showsCursor = true
                configuration.scalesToFit = false

                let cgImage = try await SCScreenshotManager.captureImage(
                    contentFilter: filter,
                    configuration: configuration
                )

                await MainActor.run {
                    let size = NSSize(width: display.width, height: display.height)
                    let nsImage = NSImage(cgImage: cgImage, size: size)
                    self.saveImage(nsImage, description: "display \(index + 1)")
                }
            } catch {
                await MainActor.run {
                    self.showError("Capture error: \(error.localizedDescription)")
                    SentrySDK.capture(error: error)
                }
            }
        }
    }

    func getAvailableDisplays() async -> [SCDisplay] {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            return content.displays
        } catch {
            return []
        }
    }

    // MARK: - ScreenCaptureKit Capture

    private func captureRectWithScreenCaptureKit(_ rect: NSRect, description: String) async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

            guard let display = content.displays.first else {
                await MainActor.run { self.showError("No display found") }
                return
            }

            let filter = SCContentFilter(display: display, excludingWindows: [])

            let configuration = SCStreamConfiguration()
            configuration.width = Int(rect.width)
            configuration.height = Int(rect.height)
            configuration.sourceRect = rect
            configuration.showsCursor = true
            configuration.scalesToFit = false

            let cgImage = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )

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

    // MARK: - Image Processing & Saving

    private func processTemporaryScreenshot(at tempPath: String, description: String) {
        defer {
            // Always clean up temp file
            try? FileManager.default.removeItem(atPath: tempPath)
        }

        guard FileManager.default.fileExists(atPath: tempPath),
              let nsImage = NSImage(contentsOfFile: tempPath) else {
            // User cancelled the capture
            return
        }

        saveImage(nsImage, description: description)
    }

    private func saveImage(_ image: NSImage, description: String) {
        // Validate save directory
        if case .failure(let error) = validateSaveDirectory(saveDirectory) {
            showError(error.localizedDescription)
            return
        }

        let filename = generateFilename()
        let fileURL = saveDirectory.appendingPathComponent(filename)

        guard let imageData = getImageData(from: image) else {
            showError("Could not process the image")
            return
        }

        // Write file on background queue to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try imageData.write(to: fileURL)

                DispatchQueue.main.async {
                    guard let self = self else { return }

                    // Copy to clipboard if enabled
                    if self.copyToClipboard {
                        self.copyImageToClipboard(image)
                    }

                    // Track recent capture
                    self.addRecentCapture(filename: filename, filePath: fileURL.path, captureType: description)

                    self.showSuccess("\(description) capture saved: \(filename)")
                    self.showFloatingPreview(image: image)
                }
            } catch {
                DispatchQueue.main.async {
                    self?.showError("Error saving: \(error.localizedDescription)")
                    SentrySDK.capture(error: error)
                }
            }
        }
    }

    private func showFloatingPreview(image: NSImage) {
        let previewWindow = FloatingPreviewWindow(image: image, autoCloseTime: floatingPreviewTime)
        previewWindow.makeKeyAndOrderFront(nil)
    }

    // MARK: - Clipboard Support

    private func copyImageToClipboard(_ image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }

    func updateCopyToClipboard(_ enabled: Bool) {
        copyToClipboard = enabled
        userDefaults.set(enabled, forKey: "copyToClipboard")
    }

    // MARK: - Recent Captures

    private func loadRecentCaptures() {
        guard let data = userDefaults.data(forKey: "recentCaptures"),
              let captures = try? JSONDecoder().decode([RecentCapture].self, from: data) else {
            return
        }
        recentCaptures = captures
    }

    private func saveRecentCaptures() {
        guard let data = try? JSONEncoder().encode(recentCaptures) else { return }
        userDefaults.set(data, forKey: "recentCaptures")
    }

    private func addRecentCapture(filename: String, filePath: String, captureType: String) {
        let capture = RecentCapture(filename: filename, filePath: filePath, captureType: captureType)
        recentCaptures.insert(capture, at: 0)
        if recentCaptures.count > Self.maxRecentCaptures {
            recentCaptures = Array(recentCaptures.prefix(Self.maxRecentCaptures))
        }
        saveRecentCaptures()
    }

    func clearRecentCaptures() {
        recentCaptures.removeAll()
        saveRecentCaptures()
    }

    func openRecentCapture(_ capture: RecentCapture) {
        let url = URL(fileURLWithPath: capture.filePath)
        NSWorkspace.shared.open(url)
    }

    func revealRecentCapture(_ capture: RecentCapture) {
        let url = URL(fileURLWithPath: capture.filePath)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    // MARK: - Filename Generation

    func generateFilename() -> String {
        var filename = filePrefix

        if includeTimestamp {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            filename += "_\(formatter.string(from: Date()))"
        } else {
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
        checkNotificationPermission { hasPermission in
            if hasPermission {
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
            } else {
                print("Success: \(message) (notification permission not granted)")
            }
        }
    }

    private func showError(_ message: String) {
        checkNotificationPermission { hasPermission in
            if hasPermission {
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
            } else {
                print("Error: \(message) (notification permission not granted)")
            }
        }
    }

    // MARK: - Settings Management

    func updatePrefix(_ newPrefix: String) {
        userDefaults.set(newPrefix, forKey: "filePrefix")
    }

    func updateSaveDirectory(_ newDirectory: URL) {
        if case .failure(let error) = validateSaveDirectory(newDirectory) {
            showError(error.localizedDescription)
            return
        }
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

    func getCurrentPrefix() -> String { return filePrefix }
    func getCurrentSaveDirectory() -> URL { return saveDirectory }
    func getCurrentIncludeTimestamp() -> Bool { return includeTimestamp }
    func getCurrentImageFormat() -> String { return imageFormat }
    func getCurrentFloatingPreviewTime() -> Double { return floatingPreviewTime }
}
