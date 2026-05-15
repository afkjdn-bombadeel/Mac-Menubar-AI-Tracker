import Foundation
import Testing
@testable import MacMenubarAITracker

struct InstalledSkillsScannerTests {
    @Test func scansSkillFilesUnderConfiguredRootOnly() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacMenubarAITrackerTests-\(UUID().uuidString)")
            .appendingPathComponent(".codex/skills")
        let skillDirectory = root.appendingPathComponent("fixture-skill")
        try FileManager.default.createDirectory(at: skillDirectory, withIntermediateDirectories: true)
        try """
        ---
        name: Fixture Skill
        description: Verifies local scanner behavior.
        tags: [fixture]
        ---
        """.write(to: skillDirectory.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: root.deletingLastPathComponent().deletingLastPathComponent())
        }

        let scanner = InstalledSkillsScanner(roots: [root])
        let records = scanner.scan()

        #expect(records.count == 1)
        #expect(records.first?.name == "Fixture Skill")
        #expect(records.first?.platform == .codex)
        #expect(records.first?.locationGroup == "~/.codex/skills")
        #expect(records.first?.tags == ["fixture"])
    }

    @Test func scansNestedSkillFilesUnderConfiguredRoot() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacMenubarAITrackerTests-\(UUID().uuidString)")
        let skillDirectory = root.appendingPathComponent("Pack/Group/nested-skill")
        try FileManager.default.createDirectory(at: skillDirectory, withIntermediateDirectories: true)
        try """
        ---
        name: Nested Fixture Skill
        description: Verifies nested local scanner behavior.
        ---
        """.write(to: skillDirectory.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let scanner = InstalledSkillsScanner(roots: [root])
        let records = scanner.scan()
        let normalizedRoot = normalizedPath(root)
        let normalizedSkillDirectory = normalizedPath(skillDirectory)

        #expect(records.map(\.name) == ["Nested Fixture Skill"])
        #expect(records.first?.localPath == normalizedSkillDirectory)
        #expect(records.first?.locationGroup == "\(normalizedRoot)/Pack")
    }

    private func normalizedPath(_ url: URL) -> String {
        let path = url.resolvingSymlinksInPath().standardizedFileURL.path(percentEncoded: false)
        guard path.count > 1, path.hasSuffix("/") else { return path }
        return String(path.dropLast())
    }
}
