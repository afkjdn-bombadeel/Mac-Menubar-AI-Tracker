import Foundation

@MainActor
final class SkillStore: ObservableObject {
    @Published private(set) var skills: [SkillRecord] = []
    @Published private(set) var projects: [ProjectRecord] = []
    @Published private(set) var isRefreshing = false

    private let homeDirectory: URL

    init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.homeDirectory = homeDirectory
    }

    func refresh(roots: [URL]? = nil) async {
        isRefreshing = true
        let resolvedRoots = roots ?? InstalledSkillsScanner.defaultRoots(homeDirectory: homeDirectory)
        let automationRoot = homeDirectory.appendingPathComponent(".codex/automations")
        let projectRoots = Self.projectRoots(from: resolvedRoots)

        let initialSnapshot = await Task.detached(priority: .userInitiated) {
            let automations = AutomationScanner(root: automationRoot).scan()
            let projects = ProjectScanner(roots: projectRoots, skills: [], automations: automations).scan()
            return (automations: automations, projects: projects)
        }.value
        projects = initialSnapshot.projects

        let skills = await Task.detached(priority: .userInitiated) {
            InstalledSkillsScanner(roots: resolvedRoots).scan()
        }.value
        let projects = await Task.detached(priority: .userInitiated) {
            ProjectScanner(roots: projectRoots, skills: skills, automations: initialSnapshot.automations).scan()
        }.value
        self.skills = skills
        self.projects = projects
        isRefreshing = false
    }

    private static func projectRoots(from roots: [URL]) -> [URL] {
        roots.filter { root in
            let path = root.path(percentEncoded: false)
            return !path.hasSuffix("/.codex/skills") && !path.hasSuffix("/.claude/skills")
        }
    }
}
