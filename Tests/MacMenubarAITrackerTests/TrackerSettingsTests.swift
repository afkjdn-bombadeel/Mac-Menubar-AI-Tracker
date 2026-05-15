import Foundation
import Testing
@testable import MacMenubarAITracker

@MainActor
struct TrackerSettingsTests {
    @Test func defaultsToCodexAndClaudeSkillRootsOnly() {
        let suiteName = "TrackerSettingsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = TrackerSettings(defaults: defaults)
        let paths = settings.scanDirectoryPaths

        #expect(paths.count == 2)
        #expect(paths.contains { $0.hasSuffix("/.codex/skills") })
        #expect(paths.contains { $0.hasSuffix("/.claude/skills") })
        #expect(!paths.contains { $0.contains("/private/workspace") })
    }

    @Test func persistsAddedDirectories() throws {
        let suiteName = "TrackerSettingsTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("TrackerSettingsTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let settings = TrackerSettings(defaults: defaults)
        settings.addDirectory(root)

        let reloaded = TrackerSettings(defaults: defaults)
        #expect(reloaded.scanDirectoryPaths.contains(root.path(percentEncoded: false)))
        #expect(reloaded.scanRoots.contains(root.standardizedFileURL))
    }
}
