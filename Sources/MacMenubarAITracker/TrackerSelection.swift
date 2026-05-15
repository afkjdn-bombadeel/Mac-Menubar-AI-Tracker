import Foundation

enum TrackerTab: String, CaseIterable, Identifiable {
    case skills = "Skills"
    case projects = "Projects"

    var id: String { rawValue }
}

enum ProjectFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case instructions = "Instructions"
    case skills = "Skills"
    case automations = "Automations"
    case configs = "Configs"
    case mcps = "MCPs"
    case warnings = "Warnings"

    var id: String { rawValue }

    var buttonWidth: CGFloat {
        switch self {
        case .all: return 44
        case .instructions: return 96
        case .skills: return 64
        case .automations: return 104
        case .configs: return 74
        case .mcps: return 58
        case .warnings: return 86
        }
    }

    static var totalBarWidth: CGFloat {
        allCases.map(\.buttonWidth).reduce(0, +) + CGFloat(allCases.count - 1) * 6 + 24
    }

    func includes(_ project: ProjectRecord) -> Bool {
        switch self {
        case .all:
            return true
        case .instructions:
            return !project.instructions.isEmpty
        case .skills:
            return !project.skills.isEmpty
        case .automations:
            return !project.automations.isEmpty
        case .configs:
            return !project.configs.isEmpty
        case .mcps:
            return !project.mcps.isEmpty
        case .warnings:
            return !project.warnings.isEmpty
        }
    }
}

enum SidebarSortMode: String, Codable, CaseIterable, Identifiable {
    case alphabeticalAscending
    case alphabeticalDescending
    case createdAscending
    case createdDescending
    case modifiedAscending
    case modifiedDescending

    var id: String { rawValue }

    var title: String {
        switch self {
        case .alphabeticalAscending: return "A to Z"
        case .alphabeticalDescending: return "Z to A"
        case .createdAscending: return "Created Oldest"
        case .createdDescending: return "Created Newest"
        case .modifiedAscending: return "Modified Oldest"
        case .modifiedDescending: return "Modified Newest"
        }
    }

    func skillComparator(_ lhs: SkillRecord, _ rhs: SkillRecord) -> Bool {
        switch self {
        case .alphabeticalAscending:
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        case .alphabeticalDescending:
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedDescending
        case .createdAscending:
            return compare(lhs.createdAt, rhs.createdAt, fallback: lhs.name, rhs.name, ascending: true)
        case .createdDescending:
            return compare(lhs.createdAt, rhs.createdAt, fallback: lhs.name, rhs.name, ascending: false)
        case .modifiedAscending:
            return compare(lhs.modifiedAt, rhs.modifiedAt, fallback: lhs.name, rhs.name, ascending: true)
        case .modifiedDescending:
            return compare(lhs.modifiedAt, rhs.modifiedAt, fallback: lhs.name, rhs.name, ascending: false)
        }
    }

    func projectComparator(_ lhs: ProjectRecord, _ rhs: ProjectRecord) -> Bool {
        switch self {
        case .alphabeticalAscending:
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        case .alphabeticalDescending:
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedDescending
        case .createdAscending:
            return compare(lhs.createdAt, rhs.createdAt, fallback: lhs.name, rhs.name, ascending: true)
        case .createdDescending:
            return compare(lhs.createdAt, rhs.createdAt, fallback: lhs.name, rhs.name, ascending: false)
        case .modifiedAscending:
            return compare(lhs.modifiedAt, rhs.modifiedAt, fallback: lhs.name, rhs.name, ascending: true)
        case .modifiedDescending:
            return compare(lhs.modifiedAt, rhs.modifiedAt, fallback: lhs.name, rhs.name, ascending: false)
        }
    }

    private func compare(_ lhsDate: Date?, _ rhsDate: Date?, fallback lhsName: String, _ rhsName: String, ascending: Bool) -> Bool {
        switch (lhsDate, rhsDate) {
        case let (lhs?, rhs?) where lhs != rhs:
            return ascending ? lhs < rhs : lhs > rhs
        case (nil, _?):
            return false
        case (_?, nil):
            return true
        default:
            return lhsName.localizedCaseInsensitiveCompare(rhsName) == .orderedAscending
        }
    }
}

enum FolderSortMode: String, Codable, CaseIterable, Identifiable {
    case alphabeticalAscending
    case alphabeticalDescending
    case countAscending
    case countDescending

    var id: String { rawValue }

    var title: String {
        switch self {
        case .alphabeticalAscending: return "Folder A to Z"
        case .alphabeticalDescending: return "Folder Z to A"
        case .countAscending: return "Fewest Skills"
        case .countDescending: return "Most Skills"
        }
    }

    func groupComparator(_ lhs: (String, [SkillRecord]), _ rhs: (String, [SkillRecord])) -> Bool {
        switch self {
        case .alphabeticalAscending:
            return lhs.0.localizedCaseInsensitiveCompare(rhs.0) == .orderedAscending
        case .alphabeticalDescending:
            return lhs.0.localizedCaseInsensitiveCompare(rhs.0) == .orderedDescending
        case .countAscending:
            return lhs.1.count == rhs.1.count
                ? lhs.0.localizedCaseInsensitiveCompare(rhs.0) == .orderedAscending
                : lhs.1.count < rhs.1.count
        case .countDescending:
            return lhs.1.count == rhs.1.count
                ? lhs.0.localizedCaseInsensitiveCompare(rhs.0) == .orderedAscending
                : lhs.1.count > rhs.1.count
        }
    }
}

struct SidebarNodeSortConfiguration: Codable, Equatable, Hashable {
    var folderSortMode: FolderSortMode? = nil
    var skillSortMode: SidebarSortMode? = nil
    var itemSortMode: SidebarSortMode? = nil
}

enum DateSummaryFormatter {
    static func summary(createdAt: Date?, modifiedAt: Date?) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        var parts: [String] = []
        if let createdAt {
            parts.append("Created \(formatter.string(from: createdAt))")
        }
        if let modifiedAt {
            parts.append("Modified \(formatter.string(from: modifiedAt))")
        }
        return parts.joined(separator: "  ")
    }
}
