import SwiftUI
import KeyboardShortcuts

struct ShortcutsSettingsTab: View {
    @ObservedObject var keyboardShortcutsManager: KeyboardShortcutsManager

    var body: some View {
        ScrollView {
            if let error = keyboardShortcutsManager.loadError {
                errorView(error)
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

    private func errorView(_ error: String) -> some View {
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
    }

    private var keyboardShortcutsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(icon: "keyboard", title: "Global keyboard shortcuts")

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
        .settingsSection()
    }

    private var shortcutsInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(icon: "info.circle", title: "Information")

            VStack(alignment: .leading, spacing: 8) {
                InfoTip(icon: "checkmark.circle.fill", color: .green, text: "Shortcuts work globally in any application")
                InfoTip(icon: "lightbulb.fill", color: .orange, text: "Screenshots are automatically saved to the configured folder")
                InfoTip(icon: "square.and.arrow.up", color: .blue, text: "Hold Space during selection to move the area")
            }
            .padding(16)
            .background(Color.accentColor.opacity(0.05))
            .cornerRadius(10)
        }
        .settingsSection()
    }
}

// MARK: - Info Tip

private struct InfoTip: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(color)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
    }
}
