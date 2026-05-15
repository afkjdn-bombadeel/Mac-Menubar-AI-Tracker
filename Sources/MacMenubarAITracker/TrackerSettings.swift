import SwiftUI

@MainActor
final class TrackerSettings: ObservableObject {
    private enum Key {
        static let scanDirectories = "settings.scanDirectories"
        static let panelOpacity = "settings.panelOpacity"
        static let backgroundColor = "settings.backgroundColor"
        static let fontColor = "settings.fontColor"
        static let fontName = "settings.fontName"
        static let fontSize = "settings.fontSize"
    }

    @Published var scanDirectoryPaths: [String] {
        didSet { defaults.set(scanDirectoryPaths, forKey: Key.scanDirectories) }
    }
    @Published var panelOpacity: Double {
        didSet { defaults.set(panelOpacity, forKey: Key.panelOpacity) }
    }
    @Published var backgroundColorHex: String {
        didSet { defaults.set(backgroundColorHex, forKey: Key.backgroundColor) }
    }
    @Published var fontColorHex: String {
        didSet { defaults.set(fontColorHex, forKey: Key.fontColor) }
    }
    @Published var fontName: String {
        didSet { defaults.set(fontName, forKey: Key.fontName) }
    }
    @Published var fontSize: Double {
        didSet { defaults.set(fontSize, forKey: Key.fontSize) }
    }

    private let defaults: UserDefaults
    private let fileManager: FileManager

    init(defaults: UserDefaults = .standard, fileManager: FileManager = .default) {
        self.defaults = defaults
        self.fileManager = fileManager

        scanDirectoryPaths = (defaults.stringArray(forKey: Key.scanDirectories) ?? [
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".codex/skills").path(percentEncoded: false),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".claude/skills").path(percentEncoded: false)
        ]).map(Self.normalizedPathString)
        panelOpacity = defaults.object(forKey: Key.panelOpacity) as? Double ?? 0.82
        backgroundColorHex = defaults.string(forKey: Key.backgroundColor) ?? "#111111"
        fontColorHex = defaults.string(forKey: Key.fontColor) ?? "#F4F4F4"
        fontName = defaults.string(forKey: Key.fontName) ?? "System"
        fontSize = defaults.object(forKey: Key.fontSize) as? Double ?? 13
    }

    var scanRoots: [URL] {
        scanDirectoryPaths
            .map(expandedPath(_:))
            .map(URL.init(fileURLWithPath:))
            .map { $0.standardizedFileURL }
            .reduce(into: []) { roots, url in
                guard fileManager.fileExists(atPath: url.path(percentEncoded: false)),
                      !roots.contains(url)
                else { return }
                roots.append(url)
            }
    }

    var backgroundColor: Color {
        Color(hex: backgroundColorHex) ?? Color(nsColor: .windowBackgroundColor)
    }

    var fontColor: Color {
        Color(hex: fontColorHex) ?? .primary
    }

    var interfaceFont: Font {
        if fontName == "System" {
            return .system(size: fontSize)
        }
        return .custom(fontName, size: fontSize)
    }

    func addDirectory(_ url: URL) {
        let path = Self.normalizedPathString(url.standardizedFileURL.path(percentEncoded: false))
        guard !scanDirectoryPaths.contains(path) else { return }
        scanDirectoryPaths.append(path)
    }

    func removeDirectory(_ path: String) {
        scanDirectoryPaths.removeAll { $0 == path }
    }

    func resetDirectories() {
        scanDirectoryPaths = [
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".codex/skills").path(percentEncoded: false),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".claude/skills").path(percentEncoded: false)
        ].map(Self.normalizedPathString)
    }

    private static func normalizedPathString(_ path: String) -> String {
        var normalized = path
        while normalized.count > 1, normalized.hasSuffix("/") {
            normalized.removeLast()
        }
        return normalized
    }

    private func expandedPath(_ path: String) -> String {
        guard path.hasPrefix("~/") else { return path }
        return fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(String(path.dropFirst(2)))
            .path(percentEncoded: false)
    }
}

struct TrackerAppearance {
    var fontName: String
    var fontSize: Double

    func font(sizeOffset: Double = 0, weight: Font.Weight? = nil) -> Font {
        let size = max(8, fontSize + sizeOffset)
        if fontName == "System" {
            return .system(size: size, weight: weight)
        }
        return .custom(fontName, size: size).weight(weight ?? .regular)
    }

    var caption2: Font { font(sizeOffset: -2) }
    var caption: Font { font(sizeOffset: -1) }
    var captionSemibold: Font { font(sizeOffset: -1, weight: .semibold) }
    var subheadlineSemibold: Font { font(sizeOffset: 0, weight: .semibold) }
    var headline: Font { font(sizeOffset: 2, weight: .semibold) }
    var title: Font { font(sizeOffset: 9, weight: .semibold) }
}

private struct TrackerAppearanceKey: EnvironmentKey {
    static let defaultValue = TrackerAppearance(fontName: "System", fontSize: 13)
}

extension EnvironmentValues {
    var trackerAppearance: TrackerAppearance {
        get { self[TrackerAppearanceKey.self] }
        set { self[TrackerAppearanceKey.self] = newValue }
    }
}

extension Color {
    init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") {
            value.removeFirst()
        }
        guard value.count == 6, let integer = Int(value, radix: 16) else { return nil }
        let red = Double((integer >> 16) & 0xFF) / 255
        let green = Double((integer >> 8) & 0xFF) / 255
        let blue = Double(integer & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }

    func hexString() -> String? {
        guard let color = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        let red = Int(round(color.redComponent * 255))
        let green = Int(round(color.greenComponent * 255))
        let blue = Int(round(color.blueComponent * 255))
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}
