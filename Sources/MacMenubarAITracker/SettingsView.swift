import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: TrackerSettings
    var refresh: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.trackerAppearance) private var appearance

    private let fontChoices = ["System", "Avenir Next", "Helvetica Neue", "Menlo", "SF Mono"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Settings")
                    .font(appearance.title)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()

            VStack(alignment: .leading, spacing: 18) {
                Text("Scan Directories")
                    .font(appearance.headline)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(settings.scanDirectoryPaths, id: \.self) { path in
                        HStack(spacing: 8) {
                            Text(displayPath(path))
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer()

                            Button {
                                settings.removeDirectory(path)
                                refresh()
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                            .help("Remove directory")
                        }
                    }

                    HStack {
                        Button {
                            addDirectory()
                        } label: {
                            Label("Add Directory", systemImage: "plus")
                        }

                        Button("Reset Defaults") {
                            settings.resetDirectories()
                            refresh()
                        }
                    }
                }
                .padding(10)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))

                Text("Appearance")
                    .font(appearance.headline)
                    .padding(.top, 4)

                VStack(spacing: 0) {
                    settingsRow("Opacity") {
                        Slider(value: $settings.panelOpacity, in: 0.35...1)
                            .frame(width: 210)
                    }

                    Divider()

                    settingsRow("Background") {
                        ColorPicker("", selection: colorBinding(\.backgroundColorHex))
                            .labelsHidden()
                    }

                    Divider()

                    settingsRow("Font Color") {
                        ColorPicker("", selection: colorBinding(\.fontColorHex))
                            .labelsHidden()
                    }

                    Divider()

                    settingsRow("Font") {
                        Picker("", selection: $settings.fontName) {
                            ForEach(fontChoices, id: \.self) { font in
                                Text(font).tag(font)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 160)
                    }

                    Divider()

                    settingsRow("Font Size \(Int(settings.fontSize))") {
                        Stepper("", value: $settings.fontSize, in: 10...20, step: 1)
                            .labelsHidden()
                    }
                }
                .padding(.horizontal, 10)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func settingsRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(title)
            Spacer()
            content()
        }
        .frame(height: 42)
    }

    private func addDirectory() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Add"

        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            settings.addDirectory(url)
        }
        refresh()
    }

    private func displayPath(_ path: String) -> String {
        path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path(percentEncoded: false), with: "~")
    }

    private func colorBinding(_ keyPath: ReferenceWritableKeyPath<TrackerSettings, String>) -> Binding<Color> {
        Binding {
            Color(hex: settings[keyPath: keyPath]) ?? .primary
        } set: { color in
            if let hex = color.hexString() {
                settings[keyPath: keyPath] = hex
            }
        }
    }
}

@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    func show(settings: TrackerSettings, refresh: @escaping () -> Void) {
        let content = SettingsView(settings: settings, refresh: refresh)
        if let window {
            (window.contentViewController as? NSHostingController<SettingsView>)?.rootView = content
            bringToFront(window)
            return
        }

        let hostingController = NSHostingController(rootView: content)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.popUpMenuWindow)) + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("TrackerSettingsWindow")
        self.window = window

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.window = nil
            }
        }

        bringToFront(window)
    }

    private func bringToFront(_ window: NSWindow) {
        NSApp.activate(ignoringOtherApps: true)
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
        }
    }
}
