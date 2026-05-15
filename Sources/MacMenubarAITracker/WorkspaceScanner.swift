import Foundation

struct WorkspaceSnapshot {
    var skills: [SkillRecord]
    var projects: [ProjectRecord]
}

struct WorkspaceScanner {
    var roots: [URL]
    var automationRoot: URL

    static func defaultScanner(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) -> WorkspaceScanner {
        WorkspaceScanner(
            roots: InstalledSkillsScanner.defaultRoots(homeDirectory: homeDirectory),
            automationRoot: homeDirectory.appendingPathComponent(".codex/automations")
        )
    }

    func scan() -> WorkspaceSnapshot {
        let skills = InstalledSkillsScanner(roots: roots).scan()
        let automations = AutomationScanner(root: automationRoot).scan()
        let projects = ProjectScanner(roots: projectRoots, skills: skills, automations: automations).scan()
        return WorkspaceSnapshot(skills: skills, projects: projects)
    }

    private var projectRoots: [URL] {
        roots.filter { root in
            let path = root.path(percentEncoded: false)
            return !path.hasSuffix("/.codex/skills") && !path.hasSuffix("/.claude/skills")
        }
    }
}

struct AutomationScanner {
    var root: URL
    private var fileManager: FileManager { .default }

    func scan() -> [AutomationRecord] {
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        return enumerator.compactMap { item -> AutomationRecord? in
            guard let url = item as? URL, url.lastPathComponent == "automation.toml" else { return nil }
            return parseAutomation(at: url)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func parseAutomation(at url: URL) -> AutomationRecord? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let fields = parseScalarFields(text)
        let id = fields["id"] ?? url.deletingLastPathComponent().lastPathComponent
        let name = fields["name"] ?? id
        let prompt = fields["prompt"] ?? ""

        return AutomationRecord(
            id: id,
            name: name,
            status: fields["status"] ?? "UNKNOWN",
            kind: fields["kind"] ?? "unknown",
            rrule: fields["rrule"] ?? "",
            readableSchedule: readableSchedule(fields["rrule"] ?? ""),
            promptPreview: preview(prompt),
            path: url.path(percentEncoded: false),
            cwds: parseStringArray(named: "cwds", in: text)
        )
    }

    private func parseScalarFields(_ text: String) -> [String: String] {
        var fields: [String: String] = [:]
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("#"),
                  let equals = trimmed.firstIndex(of: "=")
            else {
                continue
            }

            let key = trimmed[..<equals].trimmingCharacters(in: .whitespaces)
            let rawValue = trimmed[trimmed.index(after: equals)...].trimmingCharacters(in: .whitespaces)
            guard rawValue.hasPrefix("\""), rawValue.hasSuffix("\"") else {
                continue
            }
            fields[key] = String(rawValue.dropFirst().dropLast())
                .replacingOccurrences(of: "\\n", with: "\n")
                .replacingOccurrences(of: "\\\"", with: "\"")
        }
        return fields
    }

    private func parseStringArray(named key: String, in text: String) -> [String] {
        guard let line = text.components(separatedBy: .newlines).first(where: {
            $0.trimmingCharacters(in: .whitespaces).hasPrefix("\(key) = [")
        }), let start = line.firstIndex(of: "["), let end = line.lastIndex(of: "]") else {
            return []
        }

        return line[line.index(after: start)..<end]
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }
            .filter { !$0.isEmpty }
    }

    private func preview(_ text: String) -> String {
        text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func readableSchedule(_ raw: String) -> String {
        let trimmed = raw.replacingOccurrences(of: "RRULE:", with: "")
        guard !trimmed.isEmpty else { return "No schedule" }

        let parts = Dictionary(uniqueKeysWithValues: trimmed.split(separator: ";").compactMap { part -> (String, String)? in
            let pieces = part.split(separator: "=", maxSplits: 1).map(String.init)
            guard pieces.count == 2 else { return nil }
            return (pieces[0], pieces[1])
        })

        let frequency = parts["FREQ"]?.lowercased() ?? "scheduled"
        let time = readableTime(hour: parts["BYHOUR"], minute: parts["BYMINUTE"])
        let days = readableDays(parts["BYDAY"])

        switch frequency {
        case "daily":
            return time.map { "Daily at \($0)" } ?? "Daily"
        case "weekly":
            if let days, let time { return "\(days) at \(time)" }
            if let days { return days }
            if let time { return "Weekly at \(time)" }
            return "Weekly"
        case "minutely":
            if let interval = parts["INTERVAL"] { return "Every \(interval) minutes" }
            return "Every minute"
        case "hourly":
            if let interval = parts["INTERVAL"] { return "Every \(interval) hours" }
            return "Hourly"
        default:
            return raw
        }
    }

    private func readableTime(hour: String?, minute: String?) -> String? {
        guard let hourValue = hour.flatMap(Int.init) else { return nil }
        let minuteValue = minute.flatMap(Int.init) ?? 0
        let suffix = hourValue >= 12 ? "PM" : "AM"
        let displayHour = hourValue % 12 == 0 ? 12 : hourValue % 12
        return String(format: "%d:%02d %@", displayHour, minuteValue, suffix)
    }

    private func readableDays(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        let names = [
            "MO": "Mon", "TU": "Tue", "WE": "Wed", "TH": "Thu",
            "FR": "Fri", "SA": "Sat", "SU": "Sun"
        ]
        let days = raw.split(separator: ",").map { names[String($0)] ?? String($0) }
        if Set(days) == Set(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]) {
            return "Every day"
        }
        return days.joined(separator: ", ")
    }
}

struct ProjectScanner {
    var roots: [URL]
    var skills: [SkillRecord]
    var automations: [AutomationRecord]
    private var fileManager: FileManager { .default }

    func scan() -> [ProjectRecord] {
        let discovered = roots.flatMap(projectsUnderRoot(_:))
        let automationProjects = automations.flatMap(\.cwds).map { URL(fileURLWithPath: $0) }
        let allProjectURLs = (discovered + automationProjects).reduce(into: [URL]()) { urls, url in
            let normalized = url.resolvingSymlinksInPath().standardizedFileURL
            guard fileManager.fileExists(atPath: normalized.path(percentEncoded: false)),
                  !urls.contains(normalized)
            else { return }
            urls.append(normalized)
        }

        return allProjectURLs.map(buildProject(_:))
            .filter { !$0.signals.isEmpty || !$0.automations.isEmpty }
            .sorted { $0.displayPath.localizedCaseInsensitiveCompare($1.displayPath) == .orderedAscending }
    }

    private func projectsUnderRoot(_ root: URL) -> [URL] {
        let normalizedRoot = root.resolvingSymlinksInPath().standardizedFileURL
        var projectURLs = hasMarkerSignal(at: normalizedRoot) ? [normalizedRoot] : []
        guard let enumerator = fileManager.enumerator(
            at: normalizedRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsPackageDescendants]
        ) else {
            return projectURLs
        }

        for case let url as URL in enumerator {
            let directory = isDirectory(url)
            if let projectURL = projectURLForSignal(at: url, isDirectory: directory, under: normalizedRoot) {
                projectURLs.append(projectURL)
                if directory {
                    enumerator.skipDescendants()
                }
                continue
            }
            if directory, shouldSkipDirectory(url) {
                enumerator.skipDescendants()
            }
        }

        return projectURLs
    }

    private func buildProject(_ url: URL) -> ProjectRecord {
        let path = normalizedPath(url)
        let projectSkills = skills.filter { skill in
            guard let localPath = skill.localPath else { return false }
            return localPath == path || localPath.hasPrefix(path + "/")
        }
        let projectAutomations = automations.filter { automation in
            automation.cwds.contains { cwd in cwd == path || cwd.hasPrefix(path + "/") || path.hasPrefix(cwd + "/") }
        }
        let instructions = instructionFiles(in: url)
        let configs = configFiles(in: url)
        let mcps = mcpRecords(from: configs)
        let projectFiles = projectFiles(in: url)
        let warnings = warningsForProject(path: path, automations: projectAutomations, configs: configs)
        let dates = datesForProject(url)
        var signals = signalsForProject(url, projectFiles: projectFiles)
        if !projectSkills.isEmpty { signals.append(.skill) }
        if !projectAutomations.isEmpty { signals.append(.automation) }

        return ProjectRecord(
            name: url.lastPathComponent,
            path: path,
            displayPath: displayPath(path),
            signals: Array(Set(signals)).sorted { $0.rawValue < $1.rawValue },
            instructions: instructions,
            skills: projectSkills,
            automations: projectAutomations,
            configs: configs,
            mcps: mcps,
            projectFiles: projectFiles,
            warnings: warnings,
            createdAt: dates.created,
            modifiedAt: dates.modified
        )
    }

    private func isProjectRoot(_ url: URL) -> Bool {
        !signalsForProject(url).isEmpty
    }

    private func hasMarkerSignal(at url: URL) -> Bool {
        [
            ".git",
            "AGENTS.md",
            "CLAUDE.md",
            ".codex",
            ".claude",
            "SKILL.md",
            ".mcp.json",
            "mcp.json"
        ].contains { name in
            fileManager.fileExists(atPath: url.appendingPathComponent(name).path(percentEncoded: false))
        }
    }

    private func projectURLForSignal(at url: URL, isDirectory: Bool, under root: URL) -> URL? {
        let name = url.lastPathComponent
        if isDirectory {
            if [".git", ".codex", ".claude"].contains(name)
                || name.hasSuffix(".xcodeproj")
                || name.hasSuffix(".xcworkspace") {
                return canonicalProjectURL(forSignalAt: url.deletingLastPathComponent(), under: root, promotesNestedProject: true)
            }
            return nil
        }

        if ["AGENTS.md", "CLAUDE.md", "SKILL.md", ".mcp.json", "mcp.json"].contains(name) {
            return canonicalProjectURL(forSignalAt: url.deletingLastPathComponent(), under: root, promotesNestedProject: true)
        }
        if ["Package.swift", "package.json"].contains(name) {
            return canonicalProjectURL(forSignalAt: url.deletingLastPathComponent(), under: root, promotesNestedProject: false)
        }
        return nil
    }

    private func canonicalProjectURL(forSignalAt signalURL: URL, under root: URL, promotesNestedProject: Bool) -> URL? {
        let rootPath = normalizedPath(root)
        let signalPath = normalizedPath(signalURL)
        guard signalPath == rootPath || signalPath.hasPrefix(rootPath + "/") else {
            return signalURL
        }

        let relativeComponents = String(signalPath.dropFirst(rootPath.count))
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .split(separator: "/")
            .map(String.init)

        guard let projectsIndex = relativeComponents.firstIndex(of: "Projects"),
              relativeComponents.indices.contains(projectsIndex + 1)
        else {
            return promotesNestedProject ? signalURL : nil
        }

        let projectComponents = Array(relativeComponents.prefix(projectsIndex + 2))
        let projectRoot = projectComponents.reduce(root) { url, component in
            url.appendingPathComponent(component)
        }
        .resolvingSymlinksInPath()
        .standardizedFileURL

        guard promotesNestedProject,
              normalizedPath(signalURL) != normalizedPath(projectRoot),
              relativeComponents.count > projectsIndex + 2
        else {
            return projectRoot
        }
        return signalURL
    }

    private func signalsForProject(_ url: URL, projectFiles: [ProjectFileRecord]? = nil) -> [ProjectSignal] {
        var signals: [ProjectSignal] = []
        let checks: [(String, ProjectSignal)] = [
            (".git", .git),
            ("AGENTS.md", .agents),
            ("CLAUDE.md", .claude),
            (".codex", .codex),
            (".claude", .claudeConfig),
            ("Package.swift", .packageSwift),
            ("package.json", .packageJSON)
        ]

        for (name, signal) in checks where fileManager.fileExists(atPath: url.appendingPathComponent(name).path(percentEncoded: false)) {
            signals.append(signal)
        }

        if let contents = try? fileManager.contentsOfDirectory(atPath: url.path(percentEncoded: false)),
           contents.contains(where: { $0.hasSuffix(".xcodeproj") || $0.hasSuffix(".xcworkspace") }) {
            signals.append(.xcode)
        }

        for projectFile in projectFiles ?? self.projectFiles(in: url) {
            switch projectFile.name {
            case "AGENTS.md":
                signals.append(.agents)
            case "CLAUDE.md":
                signals.append(.claude)
            case "Package.swift":
                signals.append(.packageSwift)
            case "package.json":
                signals.append(.packageJSON)
            default:
                if projectFile.name.hasSuffix(".xcodeproj") || projectFile.name.hasSuffix(".xcworkspace") {
                    signals.append(.xcode)
                }
            }
        }

        return signals
    }

    private func projectFiles(in url: URL) -> [ProjectFileRecord] {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsPackageDescendants]
        ) else {
            return []
        }

        var records: [ProjectFileRecord] = []
        for case let itemURL as URL in enumerator {
            let directory = isDirectory(itemURL)
            if directory, shouldSkipDirectory(itemURL) {
                enumerator.skipDescendants()
                continue
            }

            let name = itemURL.lastPathComponent
            if directory {
                guard name.hasSuffix(".xcodeproj") || name.hasSuffix(".xcworkspace") else { continue }
            } else {
                guard ["AGENTS.md", "CLAUDE.md", "Package.swift", "package.json"].contains(name) else { continue }
            }

            records.append(
                ProjectFileRecord(
                    name: name,
                    path: normalizedPath(itemURL),
                    kind: projectFileKind(name)
                )
            )
        }

        return records.sorted { lhs, rhs in
            lhs.path.localizedCaseInsensitiveCompare(rhs.path) == .orderedAscending
        }
    }

    private func projectFileKind(_ name: String) -> String {
        switch name {
        case "AGENTS.md", "CLAUDE.md":
            return "Instructions"
        case "Package.swift":
            return "Swift package"
        case "package.json":
            return "Node package"
        default:
            if name.hasSuffix(".xcodeproj") { return "Xcode project" }
            if name.hasSuffix(".xcworkspace") { return "Xcode workspace" }
            return "Project file"
        }
    }

    private func instructionFiles(in url: URL) -> [InstructionRecord] {
        ["AGENTS.md", "CLAUDE.md"].compactMap { name in
            let file = url.appendingPathComponent(name)
            guard fileManager.fileExists(atPath: file.path(percentEncoded: false)) else { return nil }
            return InstructionRecord(name: name, path: file.path(percentEncoded: false))
        }
    }

    private func configFiles(in url: URL) -> [ConfigRecord] {
        let safeConfigCandidates: [(String, String)] = [
            (".codex/environments/environment.toml", "Codex Environment"),
            (".mcp.json", "MCP JSON"),
            ("mcp.json", "MCP JSON"),
            (".codex/mcp.json", "Codex MCP"),
            (".claude/settings.json", "Claude Settings")
        ]
        let safeConfigs: [ConfigRecord] = safeConfigCandidates.compactMap { relativePath, kind in
            let file = url.appendingPathComponent(relativePath)
            guard fileManager.fileExists(atPath: file.path(percentEncoded: false)) else { return nil }
            return ConfigRecord(name: file.lastPathComponent, path: file.path(percentEncoded: false), kind: kind, mayContainSecrets: false)
        }

        let secretMarkers: [ConfigRecord] = [
            ".env",
            ".env.local",
            ".env.development",
            ".env.production",
            ".npmrc",
            ".pypirc"
        ].compactMap { relativePath -> ConfigRecord? in
            let file = url.appendingPathComponent(relativePath)
            guard fileManager.fileExists(atPath: file.path(percentEncoded: false)) else { return nil }
            return ConfigRecord(name: file.lastPathComponent, path: file.path(percentEncoded: false), kind: "Secret-bearing config", mayContainSecrets: true)
        }

        return safeConfigs + secretMarkers
    }

    private func mcpRecords(from configs: [ConfigRecord]) -> [MCPRecord] {
        configs.compactMap { config in
            guard config.kind.localizedCaseInsensitiveContains("MCP"),
                  let text = try? String(contentsOfFile: config.path, encoding: .utf8)
            else { return nil }
            return MCPRecord(name: config.name, sourcePath: config.path, detail: mcpSummary(text))
        }
    }

    private func mcpSummary(_ text: String) -> String {
        if text.localizedCaseInsensitiveContains("mcpServers") { return "MCP servers configured; values hidden" }
        if text.localizedCaseInsensitiveContains("command") { return "Command-based MCP config; values hidden" }
        if text.localizedCaseInsensitiveContains("url") { return "URL-based MCP config; values hidden" }
        return "MCP-like config detected; preview hidden"
    }

    private func shouldSkipDirectory(_ url: URL) -> Bool {
        url.lastPathComponent.hasPrefix(".")
            || [".git", ".build", "node_modules", "DerivedData", "dist", "target", "vendor"].contains(url.lastPathComponent)
    }

    private func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path(percentEncoded: false), isDirectory: &isDirectory)
            && isDirectory.boolValue
    }

    private func displayPath(_ path: String) -> String {
        path.replacingOccurrences(of: fileManager.homeDirectoryForCurrentUser.path(percentEncoded: false), with: "~")
    }

    private func normalizedPath(_ url: URL) -> String {
        let path = url.resolvingSymlinksInPath().standardizedFileURL.path(percentEncoded: false)
        guard path.count > 1, path.hasSuffix("/") else { return path }
        return String(path.dropLast())
    }

    private func warningsForProject(path: String, automations: [AutomationRecord], configs: [ConfigRecord]) -> [String] {
        var warnings: [String] = []
        for automation in automations {
            for cwd in automation.cwds where !fileManager.fileExists(atPath: cwd) {
                warnings.append("Automation \(automation.name) references missing cwd \(displayPath(cwd))")
            }
            if automation.rrule.isEmpty {
                warnings.append("Automation \(automation.name) has no visible schedule")
            }
        }
        for config in configs where config.mayContainSecrets {
            warnings.append("Secret-bearing config present at \(displayPath(config.path)); contents not read")
        }
        return warnings
    }

    private func datesForProject(_ url: URL) -> (created: Date?, modified: Date?) {
        let values = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
        return (values?.creationDate, values?.contentModificationDate)
    }
}
