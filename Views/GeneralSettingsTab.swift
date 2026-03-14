import SwiftUI
import Sentry
import ServiceManagement

struct GeneralSettingsTab: View {
    @ObservedObject var screenshotManager: ScreenshotManager
    @Binding var filePrefix: String
    @Binding var includeTimestamp: Bool
    @Binding var selectedFormat: String
    @Binding var saveDirectory: URL
    @Binding var floatingPreviewTime: Double
    @Binding var launchAtLogin: Bool
    @Binding var showingDirectoryPicker: Bool

    let imageFormats = ["png", "jpg", "jpeg"]
    let previewTimes: [(value: Double, label: String)] = [
        (3.0, "3 seconds"),
        (5.0, "5 seconds"),
        (10.0, "10 seconds"),
        (15.0, "15 seconds"),
        (30.0, "30 seconds"),
        (0.0, "Don't close automatically")
    ]

    var body: some View {
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

    // MARK: - File Config

    private var fileConfigSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(icon: "doc.text", title: "File name")

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

                InfoBanner(
                    icon: "eye",
                    text: "Preview: \(previewFilename)",
                    backgroundColor: Color.accentColor.opacity(0.1)
                )
            }
        }
        .settingsSection()
    }

    private var previewFilename: String {
        let prefix = filePrefix.isEmpty ? "Screenshot" : filePrefix
        if includeTimestamp {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            return "\(prefix)_\(formatter.string(from: Date())).\(selectedFormat)"
        }
        return "\(prefix)_1.\(selectedFormat)"
    }

    // MARK: - Image Format

    private var imageFormatSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(icon: "photo", title: "Image format")

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
        .settingsSection()
    }

    // MARK: - Directory

    private var directorySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(icon: "folder", title: "Save Location")

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
        .settingsSection()
    }

    // MARK: - Floating Preview

    private var floatingPreviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(icon: "clock", title: "Floating preview")

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

                InfoBanner(
                    icon: "info.circle",
                    text: floatingPreviewTime == 0
                        ? "The window will remain open until you close it manually"
                        : "The window will close automatically after the selected time"
                )
            }
        }
        .settingsSection()
    }

    // MARK: - Launch at Login

    private var launchAtLoginSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(icon: "arrow.up.forward.app", title: "Launch at startup")

            Toggle("Launch ScreenCap when Mac starts up", isOn: $launchAtLogin)
                .toggleStyle(SwitchToggleStyle())

            Text("The application will run automatically in the background at login.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .settingsSection()
    }
}
