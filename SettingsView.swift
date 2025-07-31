import SwiftUI
import AppKit
import ServiceManagement
import KeyboardShortcuts
import Sentry
import Combine

// ObservableObject to safely manage keyboard shortcuts state
class KeyboardShortcutsManager: ObservableObject {
    @Published var isLoaded = false
    @Published var loadError: String? = nil
    @Published var shortcuts: [KeyboardShortcuts.Name] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Lazy initialization - only executed when needed
    }
    
    func loadShortcuts() {
        guard !isLoaded && loadError == nil else { return }
        
        // Use a small delay to avoid premature initialization
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Verify that KeyboardShortcuts is available
            let testShortcuts: [KeyboardShortcuts.Name] = [
                .captureFullScreen,
                .captureSelection,
                .captureWindow,
                .openSettings,
                .quitApp
            ]
            
            // Try to access each shortcut to verify they work
            for shortcut in testShortcuts {
                let _ = KeyboardShortcuts.getShortcut(for: shortcut)
            }
            
            print("Keyboard shortcuts loaded successfully")
            self.shortcuts = testShortcuts
            self.isLoaded = true
            self.loadError = nil
        }
    }
    
    func retry() {
        loadError = nil
        isLoaded = false
        shortcuts = []
        loadShortcuts()
    }
}

struct SettingsView: View {
    @StateObject private var screenshotManager = ScreenshotManager()
    @StateObject private var keyboardShortcutsManager = KeyboardShortcutsManager()
    @State private var filePrefix: String = ""
    @State private var includeTimestamp: Bool = false
    @State private var selectedFormat: String = "png"
    @State private var saveDirectory: URL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first ?? FileManager.default.homeDirectoryForCurrentUser
    @State private var showingDirectoryPicker = false
    @State private var selectedTab = 0
    @State private var hoveredShortcut: String? = nil
    @State private var floatingPreviewTime: Double = 10.0
    @State private var launchAtLogin = false
    
    let imageFormats = ["png", "jpg", "jpeg"]
    let previewTimes = [
        (value: 3.0, label: "3 seconds"),
        (value: 5.0, label: "5 seconds"),
        (value: 10.0, label: "10 seconds"),
        (value: 15.0, label: "15 seconds"),
        (value: 30.0, label: "30 seconds"),
        (value: 0.0, label: "Don't close automatically")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)
            
            TabView(selection: $selectedTab) {
                generalSettingsTab
                    .tag(0)
                    .tabItem {
                        Label("General", systemImage: "gear")
                    }
                
                shortcutsTab
                    .tag(1)
                    .tabItem {
                        Label("Shortcuts", systemImage: "keyboard")
                    }
            }
            .padding(.horizontal, 24)
            
            Divider()
                .padding(.top, 16)
            
            actionButtonsSection
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
        }
        .frame(width: 520, height: 580)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            loadCurrentSettings()
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
        .onChange(of: launchAtLogin) { _, newValue in
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Error configuring launch at startup: \(error)")
                SentrySDK.capture(error: error)
                launchAtLogin = !newValue
            }
        }
        .fileImporter(
            isPresented: $showingDirectoryPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleDirectorySelection(result)
        }
    }
    
    private var headerView: some View {
        HStack {
            Image(systemName: "camera.aperture")
                .font(.system(size: 28))
                .foregroundColor(.accentColor)
                .symbolRenderingMode(.hierarchical)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("ScreenCap")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Settings")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    private var generalSettingsTab: some View {
        ScrollView {
            VStack(spacing: 20) {
                fileConfigSection
                imageFormatSection
                directorySection
                floatingPreviewSection
                launchAtLoginSection
            }
            .padding(.vertical, 16)
        }
    }
    
    private var fileConfigSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "doc.text")
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
                Text("File name")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Prefix")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    
                    TextField("Example: Screenshot", text: $filePrefix)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: filePrefix) { _, newValue in
                            screenshotManager.updatePrefix(newValue)
                        }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: $includeTimestamp) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Include date and time")
                                .font(.system(size: 14))
                            Text("Add a unique timestamp to each file")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    .toggleStyle(SwitchToggleStyle())
                    .onChange(of: includeTimestamp) { _, newValue in
                        screenshotManager.updateIncludeTimestamp(newValue)
                    }
                }
                
                HStack {
                    Image(systemName: "eye")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("Preview: ")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text(getPreviewFilename())
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.accentColor)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var imageFormatSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "photo")
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
                Text("Image format")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            HStack(spacing: 12) {
                ForEach(imageFormats, id: \.self) { format in
                    Button(action: {
                        selectedFormat = format
                        screenshotManager.updateImageFormat(format)
                    }) {
                        VStack(spacing: 6) {
                            Image(systemName: format == "png" ? "doc.richtext" : "photo")
                                .font(.system(size: 20))
                                .foregroundColor(selectedFormat == format ? .white : .accentColor)
                            
                            Text(format.uppercased())
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(selectedFormat == format ? .white : .primary)
                            
                            Text(format == "png" ? "Lossless" : "Compressed")
                                .font(.system(size: 10))
                                .foregroundColor(selectedFormat == format ? .white.opacity(0.9) : .secondary)
                        }
                        .frame(width: 80, height: 70)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedFormat == format ? Color.accentColor : Color.gray.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(selectedFormat == format ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var directorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "folder")
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
                Text("Save Location")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.accentColor)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(saveDirectory.lastPathComponent)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Text(saveDirectory.path)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    
                    Spacer()
                    
                    Button(action: { showingDirectoryPicker = true }) {
                        Text("Change")
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.bordered)
                }
                .padding(16)
                .background(Color.accentColor.opacity(0.05))
                .cornerRadius(10)
                
                HStack(spacing: 8) {
                    Button(action: {
                        let opened = NSWorkspace.shared.open(saveDirectory)
                        if !opened {
                            print("Could not open directory: \(saveDirectory)")
                            let error = NSError(domain: "ScreenCap", code: 101, userInfo: [NSLocalizedDescriptionKey: "Could not open directory in Finder"])
                            SentrySDK.capture(error: error)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.forward.square")
                                .font(.system(size: 12))
                            Text("Open in Finder")
                                .font(.system(size: 12))
                        }
                    }
                    .buttonStyle(.link)
                    
                    Spacer()
                }
            }
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var floatingPreviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock")
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
                Text("Floating preview")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Time before auto-close")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                Picker("", selection: $floatingPreviewTime) {
                    ForEach(previewTimes, id: \.value) { time in
                        Text(time.label)
                            .tag(time.value)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .onChange(of: floatingPreviewTime) { _, newValue in
                    screenshotManager.updateFloatingPreviewTime(newValue)
                }
                
                HStack {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text(floatingPreviewTime == 0 ? 
                         "The window will remain open until you close it manually" :
                        "The window will close automatically after the selected time")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var launchAtLoginSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
                Text("Launch at startup")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            Toggle("Launch ScreenCap when Mac starts up", isOn: $launchAtLogin)
                .toggleStyle(SwitchToggleStyle())
            
            Text("The application will run automatically in the background at login.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var shortcutsTab: some View {
        ScrollView {
            if let error = keyboardShortcutsManager.loadError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                    
                    Text("Error loading shortcuts")
                        .font(.headline)
                    
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Retry") {
                        keyboardShortcutsManager.retry()
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else if keyboardShortcutsManager.isLoaded {
                VStack(spacing: 20) {
                    keyboardShortcutsSection
                    shortcutsInfoSection
                }
                .padding(.vertical, 16)
            } else {
                ProgressView("Loading shortcuts...")
                    .progressViewStyle(.circular)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            keyboardShortcutsManager.loadShortcuts()
        }
    }
    
    private var keyboardShortcutsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "keyboard")
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
                Text("Global keyboard shortcuts")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                if keyboardShortcutsManager.isLoaded {
                    SafeKeyboardShortcutRecorder("Full Screen Capture:", name: .captureFullScreen)
                    SafeKeyboardShortcutRecorder("Selection Capture:", name: .captureSelection)
                    SafeKeyboardShortcutRecorder("Window Capture:", name: .captureWindow)
                    SafeKeyboardShortcutRecorder("Open Settings:", name: .openSettings)
                    SafeKeyboardShortcutRecorder("Quit App:", name: .quitApp)
                } else {
                    ForEach(0..<5, id: \.self) { _ in
                        HStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 20)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var shortcutsInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle")
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
                Text("Information")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                    Text("Shortcuts work globally in any application")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                    Text("Screenshots are automatically saved to the configured folder")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                    Text("Hold Space during selection to move the area")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .background(Color.accentColor.opacity(0.05))
            .cornerRadius(10)
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var actionButtonsSection: some View {
        HStack(spacing: 12) {
            Button(action: {
                screenshotManager.captureSelection()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 14))
                    Text("Test Capture")
                        .font(.system(size: 14, weight: .medium))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Spacer()
            
            Button(action: {
                NSApp.keyWindow?.close()
            }) {
                Text("Close")
                    .font(.system(size: 14))
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .keyboardShortcut(.escape)
        }
    }
    
    private func handleDirectorySelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                saveDirectory = url
                screenshotManager.updateSaveDirectory(url)
            }
        case .failure(let error):
            print("Error selecting directory: \(error)")
            SentrySDK.capture(error: error)
        }
    }
    
    private func loadCurrentSettings() {
        filePrefix = screenshotManager.getCurrentPrefix()
        includeTimestamp = screenshotManager.getCurrentIncludeTimestamp()
        selectedFormat = screenshotManager.getCurrentImageFormat()
        saveDirectory = screenshotManager.getCurrentSaveDirectory()
        floatingPreviewTime = screenshotManager.getCurrentFloatingPreviewTime()
    }
    
    private func getPreviewFilename() -> String {
        let prefix = filePrefix.isEmpty ? "Screenshot" : filePrefix
        if includeTimestamp {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let timestamp = formatter.string(from: Date())
            return "\(prefix)_\(timestamp).\(selectedFormat)"
        } else {
            return "\(prefix)_1.\(selectedFormat)"
        }
    }
}

// Safe wrapper for KeyboardShortcuts.Recorder
struct SafeKeyboardShortcutRecorder: View {
    let title: String
    let name: KeyboardShortcuts.Name
    @State private var hasError = false
    @State private var isInitialized = false
    
    init(_ title: String, name: KeyboardShortcuts.Name) {
        self.title = title
        self.name = name
    }
    
    var body: some View {
        Group {
            if hasError {
                HStack {
                    Text(title)
                    Spacer()
                    Text("Error loading shortcut")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Button("Retry") {
                        retryInitialization()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
                .padding(.vertical, 2)
            } else if isInitialized {
                KeyboardShortcuts.Recorder(title, name: name)
            } else {
                HStack {
                    Text(title)
                    Spacer()
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.5)
                }
                .padding(.vertical, 2)
                .onAppear {
                    initializeShortcut()
                }
            }
        }
    }
    
    private func initializeShortcut() {
        // Use a small delay to avoid premature initialization
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            // Verify that the shortcut can be initialized
            let _ = KeyboardShortcuts.getShortcut(for: name)
            print("Successfully initialized shortcut: \(name)")
            isInitialized = true
            hasError = false
        }
    }
    
    private func retryInitialization() {
        hasError = false
        isInitialized = false
        initializeShortcut()
    }
}

#Preview {
    SettingsView()
}