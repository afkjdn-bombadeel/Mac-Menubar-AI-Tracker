import Foundation

struct SidebarTreeNode: Identifiable, Hashable {
    var id: String
    var title: String
    var displayPath: String
    var skill: SkillRecord?
    var project: ProjectRecord?
    var children: [SidebarTreeNode]

    var isLeaf: Bool {
        skill != nil || project != nil
    }

    var itemCount: Int {
        (isLeaf ? 1 : 0) + children.map(\.itemCount).reduce(0, +)
    }
}

enum SidebarTreeBuilder {
    static func skillTree(skills: [SkillRecord], roots: [URL]) -> [SidebarTreeNode] {
        buildTree(roots: roots, items: skills.compactMap { skill in
            guard let path = skill.localPath else { return nil }
            return SidebarTreeItem(id: skill.id, path: path, skill: skill, project: nil)
        })
    }

    static func projectTree(projects: [ProjectRecord], roots: [URL]) -> [SidebarTreeNode] {
        buildTree(roots: roots, items: projects.map {
            SidebarTreeItem(id: $0.id, path: $0.path, skill: nil, project: $0)
        })
    }

    private static func buildTree(roots: [URL], items: [SidebarTreeItem]) -> [SidebarTreeNode] {
        var builders: [String: NodeBuilder] = [:]

        for item in items {
            let match = bestRoot(for: item.path, roots: roots)
            let rootPath = match?.path ?? parentPath(for: item.path)
            let rootTitle = URL(fileURLWithPath: rootPath).lastPathComponent
            let components = item.path == rootPath ? [] : relativePathComponents(path: item.path, rootPath: rootPath)

            var root = builders[rootPath] ?? NodeBuilder(
                id: "folder:\(rootPath)",
                title: rootTitle,
                displayPath: rootPath
            )
            root.insert(item: item, components: components, basePath: rootPath)
            builders[rootPath] = root
        }

        return builders.values
            .map { $0.node() }
            .sorted(by: sortNodes)
    }

    private static func bestRoot(for path: String, roots: [URL]) -> (path: String, title: String)? {
        roots
            .map { root -> (path: String, title: String) in
                let standardized = normalizedPath(root)
                return (standardized, displayPath(standardized))
            }
            .filter { root in path == root.path || path.hasPrefix(root.path + "/") }
            .sorted { $0.path.count < $1.path.count }
            .first
    }

    private static func relativePathComponents(path: String, rootPath: String) -> [String] {
        let relative: String
        if path == rootPath {
            relative = URL(fileURLWithPath: path).lastPathComponent
        } else {
            relative = String(path.dropFirst(rootPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        return relative.split(separator: "/").map(String.init)
    }

    private static func parentPath(for path: String) -> String {
        URL(fileURLWithPath: path).deletingLastPathComponent().path(percentEncoded: false)
    }

    private static func normalizedPath(_ url: URL) -> String {
        let path = url.resolvingSymlinksInPath().standardizedFileURL.path(percentEncoded: false)
        guard path.count > 1, path.hasSuffix("/") else { return path }
        return String(path.dropLast())
    }

    private static func displayPath(_ path: String) -> String {
        let homePath = FileManager.default.homeDirectoryForCurrentUser.path(percentEncoded: false)
        if path == homePath { return "~" }
        if path.hasPrefix(homePath + "/") {
            return "~/" + String(path.dropFirst(homePath.count + 1))
        }
        return path
    }

    private static func sortNodes(_ lhs: SidebarTreeNode, _ rhs: SidebarTreeNode) -> Bool {
        switch (lhs.isLeaf, rhs.isLeaf) {
        case (false, true):
            return true
        case (true, false):
            return false
        default:
            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
    }
}

private struct SidebarTreeItem {
    var id: String
    var path: String
    var skill: SkillRecord?
    var project: ProjectRecord?
}

private struct NodeBuilder {
    var id: String
    var title: String
    var displayPath: String
    var skill: SkillRecord?
    var project: ProjectRecord?
    var children: [String: NodeBuilder] = [:]

    mutating func insert(item: SidebarTreeItem, components: [String], basePath: String) {
        guard let head = components.first else {
            skill = item.skill
            project = item.project
            return
        }

        let childPath = basePath + "/" + head
        var child = children[head] ?? NodeBuilder(
            id: "folder:\(childPath)",
            title: head,
            displayPath: childPath
        )

        if components.count == 1 {
            child.id = item.id
            child.skill = item.skill
            child.project = item.project
        } else {
            child.insert(item: item, components: Array(components.dropFirst()), basePath: childPath)
        }

        children[head] = child
    }

    func node() -> SidebarTreeNode {
        SidebarTreeNode(
            id: id,
            title: title,
            displayPath: displayPath,
            skill: skill,
            project: project,
            children: children.values.map { $0.node() }.sorted(by: { lhs, rhs in
                switch (lhs.isLeaf, rhs.isLeaf) {
                case (false, true):
                    return true
                case (true, false):
                    return false
                default:
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
            })
        )
    }
}
