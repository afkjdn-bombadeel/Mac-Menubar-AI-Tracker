import Foundation

@MainActor
final class SkillStore: ObservableObject {
    @Published private(set) var skills: [SkillRecord] = []
    @Published private(set) var projects: [ProjectRecord] = []
    @Published private(set) var isRefreshing = false

    private let homeDirectory: URL
    private let projectScanTimeoutNanoseconds: UInt64 = 8_000_000_000

    init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.homeDirectory = homeDirectory
    }

    func refresh(roots: [URL]? = nil) async {
        isRefreshing = true
        let resolvedRoots = roots ?? InstalledSkillsScanner.defaultRoots(homeDirectory: homeDirectory)
        let automationRoot = homeDirectory.appendingPathComponent(".codex/automations")
        let projectRoots = Self.projectRoots(from: resolvedRoots)

        async let automationsTask = Task.detached(priority: .userInitiated) {
            AutomationScanner(root: automationRoot).scan()
        }.value
        async let skillsTask = Task.detached(priority: .userInitiated) {
            InstalledSkillsScanner(roots: resolvedRoots).scan()
        }.value

        let automations = await automationsTask
        let skills = await skillsTask
        self.skills = skills

        projects = await projectScan(
            roots: projectRoots,
            skills: skills,
            automations: automations
        ) ?? projects
        isRefreshing = false
    }

    private func projectScan(
        roots: [URL],
        skills: [SkillRecord],
        automations: [AutomationRecord]
    ) async -> [ProjectRecord]? {
        let timeout = projectScanTimeoutNanoseconds
        return await withCheckedContinuation { continuation in
            let box = ProjectScanContinuationBox(continuation: continuation)

            DispatchQueue.global(qos: .userInitiated).async {
                let projects = ProjectScanner(roots: roots, skills: skills, automations: automations).scan()
                box.resume(projects)
            }

            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + .nanoseconds(Int(timeout))) {
                box.resume(nil)
            }
        }
    }

    private static func projectRoots(from roots: [URL]) -> [URL] {
        roots.filter { root in
            let path = root.path(percentEncoded: false)
            return !path.hasSuffix("/.codex/skills") && !path.hasSuffix("/.claude/skills")
        }
    }
}

private final class ProjectScanContinuationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var didResume = false
    private let continuation: CheckedContinuation<[ProjectRecord]?, Never>

    init(continuation: CheckedContinuation<[ProjectRecord]?, Never>) {
        self.continuation = continuation
    }

    func resume(_ result: [ProjectRecord]?) {
        lock.lock()
        defer { lock.unlock() }
        guard !didResume else { return }
        didResume = true
        continuation.resume(returning: result)
    }
}
