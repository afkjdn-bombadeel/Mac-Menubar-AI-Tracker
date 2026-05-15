import Foundation

enum SkillPlatform: String, Codable, CaseIterable, Hashable {
    case codex = "Codex"
    case claude = "Claude"
    case other = "Other"
}

enum SkillSource: Codable, Hashable {
    case local(path: String)
}

struct SkillRecord: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var summary: String
    var platform: SkillPlatform
    var source: SkillSource
    var localPath: String?
    var locationGroup: String
    var tags: [String]
    var lastSeenAt: Date
    var createdAt: Date?
    var modifiedAt: Date?
}

enum ProjectSignal: String, Codable, Hashable, CaseIterable {
    case git = ".git"
    case agents = "AGENTS.md"
    case claude = "CLAUDE.md"
    case codex = ".codex"
    case claudeConfig = ".claude"
    case skill = "SKILL.md"
    case automation = "Automation"
    case packageSwift = "Package.swift"
    case packageJSON = "package.json"
    case xcode = "Xcode"
}

struct InstructionRecord: Identifiable, Codable, Hashable {
    var id: String { path }
    var name: String
    var path: String
}

struct ConfigRecord: Identifiable, Codable, Hashable {
    var id: String { path }
    var name: String
    var path: String
    var kind: String
    var mayContainSecrets: Bool
}

struct MCPRecord: Identifiable, Codable, Hashable {
    var id: String { "\(sourcePath):\(name)" }
    var name: String
    var sourcePath: String
    var detail: String
}

struct ProjectFileRecord: Identifiable, Codable, Hashable {
    var id: String { path }
    var name: String
    var path: String
    var kind: String
}

struct AutomationRecord: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var status: String
    var kind: String
    var rrule: String
    var readableSchedule: String
    var promptPreview: String
    var path: String
    var cwds: [String]
}

struct ProjectRecord: Identifiable, Codable, Hashable {
    var id: String { path }
    var name: String
    var path: String
    var displayPath: String
    var signals: [ProjectSignal]
    var instructions: [InstructionRecord]
    var skills: [SkillRecord]
    var automations: [AutomationRecord]
    var configs: [ConfigRecord]
    var mcps: [MCPRecord]
    var projectFiles: [ProjectFileRecord]
    var warnings: [String]
    var createdAt: Date?
    var modifiedAt: Date?
}
