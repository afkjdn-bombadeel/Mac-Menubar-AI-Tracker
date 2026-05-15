import Foundation
import Testing
@testable import MacMenubarAITracker

struct WorkspaceScannerTests {
    @Test func projectScannerFindsNestedProjectsUnderConfiguredRoot() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("WorkspaceScannerTests-\(UUID().uuidString)")
        let directProject = root.appendingPathComponent("DirectProject")
        let nestedProject = root
            .appendingPathComponent("Group")
            .appendingPathComponent("NestedProject")
        let ignoredProject = root
            .appendingPathComponent("node_modules")
            .appendingPathComponent("IgnoredProject")

        try FileManager.default.createDirectory(at: directProject, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nestedProject, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: ignoredProject, withIntermediateDirectories: true)
        try "# Instructions".write(to: directProject.appendingPathComponent("AGENTS.md"), atomically: true, encoding: .utf8)
        try "# Instructions".write(to: nestedProject.appendingPathComponent("AGENTS.md"), atomically: true, encoding: .utf8)
        try "".write(to: ignoredProject.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let projects = ProjectScanner(roots: [root], skills: [], automations: []).scan()
        let names = Set(projects.map(\.name))

        #expect(names.contains("DirectProject"))
        #expect(names.contains("NestedProject"))
        #expect(!names.contains("IgnoredProject"))
    }

    @Test func projectScannerPromotesSignalsUnderProjectsDirectoryToProjectRoot() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("WorkspaceScannerTests-\(UUID().uuidString)")
        let projectRoot = root
            .appendingPathComponent("Projects")
            .appendingPathComponent("holographic-screen")
        let nestedPackage = projectRoot
            .appendingPathComponent("macos")
            .appendingPathComponent("AgentDeck")

        try FileManager.default.createDirectory(at: nestedPackage, withIntermediateDirectories: true)
        try "".write(to: nestedPackage.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let projects = ProjectScanner(roots: [root], skills: [], automations: []).scan()

        #expect(projects.map(\.name) == ["holographic-screen"])
        let project = try #require(projects.first)
        #expect(project.path == normalizedPath(projectRoot))
        #expect(project.signals.contains(.packageSwift))
        #expect(project.projectFiles.map(\.path).contains(normalizedPath(nestedPackage.appendingPathComponent("Package.swift"))))
    }

    @Test func packageOnlyToolFoldersDoNotCreateProjects() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("WorkspaceScannerTests-\(UUID().uuidString)")
        let toolPackage = root
            .appendingPathComponent("Tooling")
            .appendingPathComponent("Arduino")
            .appendingPathComponent("Arduino15")
            .appendingPathComponent("packages")
            .appendingPathComponent("esp32")
            .appendingPathComponent("tools")
            .appendingPathComponent("xtensa-esp-elf-gdb")
            .appendingPathComponent("16.3_20250913")

        try FileManager.default.createDirectory(at: toolPackage, withIntermediateDirectories: true)
        try "{}".write(to: toolPackage.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let projects = ProjectScanner(roots: [root], skills: [], automations: []).scan()

        #expect(projects.isEmpty)
    }

    @Test func nestedAgentMarkersCreateExpandableChildProjects() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("WorkspaceScannerTests-\(UUID().uuidString)")
        let parent = root
            .appendingPathComponent("Projects")
            .appendingPathComponent("ParentProject")
        let child = parent
            .appendingPathComponent("tools")
            .appendingPathComponent("NestedAgent")

        try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
        try "# Parent".write(to: parent.appendingPathComponent("AGENTS.md"), atomically: true, encoding: .utf8)
        try "# Child".write(to: child.appendingPathComponent("CLAUDE.md"), atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: root)
        }

        let projects = ProjectScanner(roots: [root], skills: [], automations: []).scan()
        let tree = SidebarTreeBuilder.projectTree(projects: projects, roots: [root])

        #expect(Set(projects.map(\.name)) == ["ParentProject", "NestedAgent"])
        let workspace = try #require(tree.first)
        let projectsFolder = try #require(workspace.children.first { $0.title == "Projects" })
        let parentNode = try #require(projectsFolder.children.first { $0.title == "ParentProject" })
        #expect(parentNode.children.map(\.title) == ["tools"])
        #expect(parentNode.children[0].children.map(\.title) == ["NestedAgent"])
    }

    private func normalizedPath(_ url: URL) -> String {
        let path = url.resolvingSymlinksInPath().standardizedFileURL.path(percentEncoded: false)
        guard path.count > 1, path.hasSuffix("/") else { return path }
        return String(path.dropLast())
    }
}
