import SwiftUI
import AppKit
import ServiceManagement
import KeyboardShortcuts
import Sentry

struct SettingsView: View {
    @StateObject private var screenshotManager = ScreenshotManager()
    @StateObject private var keyboardShortcutsManager = KeyboardShortcutsManager()
    @State private var filePrefix: String = ""
    @State private var includeTimestamp: Bool = false
    @State private var selectedFormat: String = "png"
    @State private var saveDirectory: URL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first ?? FileManager.default.homeDirectoryForCurrentUser
    @State private var showingDirectoryPicker = false
    @State private var selectedTab = 0
    @State private var floatingPreviewTime: Double = 10.0
    @State private var launchAtLogin = false

    var body: some View {
        VStack(spacing: 0) {
            headerView
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)

            TabView(selection: $selectedTab) {
                GeneralSettingsTab(
                    screenshotManager: screenshotManager,
                    filePrefix: $filePrefix,
                    includeTimestamp: $includeTimestamp,
                    selectedFormat: $selectedFormat,
                    saveDirectory: $saveDirectory,
                    floatingPreviewTime: $floatingPreviewTime,
                    launchAtLogin: $launchAtLogin,
                    showingDirectoryPicker: $showingDirectoryPicker
                )
                .tag(0)
                .tabItem {
                    Label("General", systemImage: "gear")
                }

                ShortcutsSettingsTab(keyboardShortcutsManager: keyboardShortcutsManager)
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

    // MARK: - Header

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

    // MARK: - Action Buttons

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

    // MARK: - Helpers

    private func handleDirectorySelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                saveDirectory = url
                screenshotManager.updateSaveDirectory(url)
            }
        case .failure(let error):
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
}

#Preview {
    SettingsView()
}
