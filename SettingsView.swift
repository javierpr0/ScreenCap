import SwiftUI
import AppKit
import ServiceManagement
import KeyboardShortcuts
import Sentry

struct SettingsView: View {
    @StateObject private var screenshotManager = ScreenshotManager()
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
        (value: 3.0, label: "3 segundos"),
        (value: 5.0, label: "5 segundos"),
        (value: 10.0, label: "10 segundos"),
        (value: 15.0, label: "15 segundos"),
        (value: 30.0, label: "30 segundos"),
        (value: 0.0, label: "No cerrar automáticamente")
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
                        Label("Atajos", systemImage: "keyboard")
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
                print("Error al configurar lanzamiento al inicio: \(error)")
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
                
                Text("Configuración")
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
                Text("Nombre de archivo")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Prefijo")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    
                    TextField("Ejemplo: Captura", text: $filePrefix)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: filePrefix) { _, newValue in
                            screenshotManager.updatePrefix(newValue)
                        }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: $includeTimestamp) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Incluir fecha y hora")
                                .font(.system(size: 14))
                            Text("Añade un timestamp único a cada archivo")
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
                    Text("Vista previa: ")
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
                Text("Formato de imagen")
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
                            
                            Text(format == "png" ? "Sin pérdida" : "Comprimido")
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
                Text("Ubicación de guardado")
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
                        Text("Cambiar")
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
                            print("No se pudo abrir el directorio: \(saveDirectory)")
                            let error = NSError(domain: "ScreenCap", code: 101, userInfo: [NSLocalizedDescriptionKey: "No se pudo abrir el directorio en Finder"])
                            SentrySDK.capture(error: error)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.forward.square")
                                .font(.system(size: 12))
                            Text("Abrir en Finder")
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
                Text("Vista previa flotante")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Tiempo antes de cerrar automáticamente")
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
                         "La ventana permanecerá abierta hasta que la cierres manualmente" :
                         "La ventana se cerrará automáticamente después del tiempo seleccionado")
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
                Text("Lanzamiento al inicio")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            Toggle("Iniciar ScreenCap al encender la Mac", isOn: $launchAtLogin)
                .toggleStyle(SwitchToggleStyle())
            
            Text("La aplicación se ejecutará automáticamente en segundo plano al iniciar sesión.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    @State private var isShortcutsTabLoaded = false

    private var shortcutsTab: some View {
        ScrollView {
            if isShortcutsTabLoaded {
                VStack(spacing: 20) {
                    keyboardShortcutsSection
                    shortcutsInfoSection
                }
                .padding(.vertical, 16)
            } else {
                ProgressView()
                    .progressViewStyle(.circular)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            print("Shortcuts tab appeared")
            isShortcutsTabLoaded = true
        }
    }
    
    private var keyboardShortcutsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "keyboard")
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
                Text("Atajos de teclado globales")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                KeyboardShortcuts.Recorder("Captura pantalla completa:", name: .captureFullScreen)
                KeyboardShortcuts.Recorder("Captura de selección:", name: .captureSelection)
                KeyboardShortcuts.Recorder("Captura de ventana:", name: .captureWindow)
                KeyboardShortcuts.Recorder("Abrir configuración:", name: .openSettings)
                KeyboardShortcuts.Recorder("Salir de la app:", name: .quitApp)
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
                Text("Información")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                    Text("Los atajos funcionan globalmente en cualquier aplicación")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                    Text("Las capturas se guardan automáticamente en la carpeta configurada")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                    Text("Mantén presionado Espacio durante la selección para mover el área")
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
                    Text("Probar Captura")
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
                Text("Cerrar")
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
        let prefix = filePrefix.isEmpty ? "Captura" : filePrefix
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

#Preview {
    SettingsView()
}