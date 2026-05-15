import Foundation

struct InstalledSkillsScanner {
    var roots: [URL]
    private var fileManager: FileManager { .default }

    static func defaultRoots(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> [URL] {
        let candidateRoots = [
            homeDirectory.appendingPathComponent(".codex/skills"),
            homeDirectory.appendingPathComponent(".claude/skills")
        ]

        return candidateRoots.reduce(into: []) { roots, url in
            let normalized = url.standardizedFileURL
            guard FileManager.default.fileExists(atPath: normalized.path(percentEncoded: false)),
                  !roots.contains(normalized)
            else {
                return
            }
            roots.append(normalized)
        }
    }

    func scan() -> [SkillRecord] {
        roots.flatMap(scanRoot(_:)).sorted { lhs, rhs in
            if lhs.locationGroup != rhs.locationGroup {
                return lhs.locationGroup.localizedCaseInsensitiveCompare(rhs.locationGroup) == .orderedAscending
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private func scanRoot(_ root: URL) -> [SkillRecord] {
        let normalizedRoot = root.resolvingSymlinksInPath().standardizedFileURL
        guard let enumerator = fileManager.enumerator(
            at: normalizedRoot,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsPackageDescendants]
        ) else {
            return []
        }

        var records: [SkillRecord] = []
        for case let fileURL as URL in enumerator {
            if shouldSkipDirectory(fileURL) {
                enumerator.skipDescendants()
                continue
            }

            guard fileURL.lastPathComponent == "SKILL.md" else {
                continue
            }

            guard isAllowedSkillFile(fileURL, under: root),
                  let markdown = try? String(contentsOf: fileURL, encoding: .utf8)
            else {
                continue
            }

            let directory = fileURL.deletingLastPathComponent()
            let parsed = SkillParser.parse(markdown: markdown, fallbackName: directory.lastPathComponent)
            let path = normalizedPath(directory)
            let dates = datesForURL(directory)

            records.append(
                SkillRecord(
                    id: "\(platform(for: root).rawValue):\(path)",
                    name: parsed.name,
                    summary: parsed.summary,
                    platform: platform(for: root),
                    source: .local(path: path),
                    localPath: path,
                    locationGroup: locationGroup(for: directory, root: normalizedRoot),
                    tags: parsed.tags,
                    lastSeenAt: Date(),
                    createdAt: dates.created,
                    modifiedAt: dates.modified
                )
            )
        }
        return records
    }

    private func shouldSkipDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path(percentEncoded: false), isDirectory: &isDirectory),
              isDirectory.boolValue
        else {
            return false
        }
        if url.lastPathComponent.hasPrefix(".") {
            return true
        }

        return [
            ".build",
            ".git",
            ".svn",
            ".worktrees",
            "DerivedData",
            "dist",
            "node_modules",
            "Pods",
            "target",
            "vendor"
        ].contains(url.lastPathComponent)
    }

    private func isAllowedSkillFile(_ fileURL: URL, under root: URL) -> Bool {
        let relativePath = fileURL.resolvingSymlinksInPath().path(percentEncoded: false)
        let rootPath = root.resolvingSymlinksInPath().path(percentEncoded: false)
        return relativePath.hasPrefix(rootPath) && !relativePath.contains("/.env")
    }

    private func platform(for root: URL) -> SkillPlatform {
        let path = root.path(percentEncoded: false)
        if path.contains(".codex") { return .codex }
        if path.contains(".claude") { return .claude }
        return .other
    }

    private func locationGroup(for directory: URL, root: URL) -> String {
        let rootPath = normalizedPath(root)
        let homePath = fileManager.homeDirectoryForCurrentUser.path(percentEncoded: false)
        let displayRoot = rootPath.replacingOccurrences(of: homePath, with: "~")

        if rootPath.hasSuffix("/.codex/skills") { return "~/.codex/skills" }
        if rootPath.hasSuffix("/.claude/skills") { return "~/.claude/skills" }

        let relative = normalizedPath(directory)
            .replacingOccurrences(of: rootPath, with: "")
            .split(separator: "/")
            .map(String.init)

        if let projectName = relative.first {
            return "\(displayRoot)/\(projectName)"
        }

        return displayRoot
    }

    private func datesForURL(_ url: URL) -> (created: Date?, modified: Date?) {
        let values = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
        return (values?.creationDate, values?.contentModificationDate)
    }

    private func normalizedPath(_ url: URL) -> String {
        let path = url.resolvingSymlinksInPath().standardizedFileURL.path(percentEncoded: false)
        guard path.count > 1, path.hasSuffix("/") else { return path }
        return String(path.dropLast())
    }
}
