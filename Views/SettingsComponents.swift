import SwiftUI
import KeyboardShortcuts
import Sentry
import Combine

// MARK: - Section Style ViewModifier

struct SettingsSectionStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
    }
}

extension View {
    func settingsSection() -> some View {
        modifier(SettingsSectionStyle())
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let icon: String
    let title: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.accentColor)
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Info Banner

struct InfoBanner: View {
    let icon: String
    let text: String
    var iconColor: Color = .secondary
    var backgroundColor: Color = Color.secondary.opacity(0.1)

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(iconColor)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(backgroundColor)
        .cornerRadius(8)
    }
}

// MARK: - Keyboard Shortcuts Manager

class KeyboardShortcutsManager: ObservableObject {
    @Published var isLoaded = false
    @Published var loadError: String? = nil
    @Published var shortcuts: [KeyboardShortcuts.Name] = []

    private var cancellables = Set<AnyCancellable>()

    func loadShortcuts() {
        guard !isLoaded && loadError == nil else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let testShortcuts: [KeyboardShortcuts.Name] = [
                .captureFullScreen,
                .captureSelection,
                .captureWindow,
                .openSettings,
                .quitApp
            ]

            for shortcut in testShortcuts {
                let _ = KeyboardShortcuts.getShortcut(for: shortcut)
            }

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

// MARK: - Safe Keyboard Shortcut Recorder

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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let _ = KeyboardShortcuts.getShortcut(for: name)
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
