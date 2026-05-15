import Foundation
import Testing
@testable import MacMenubarAITracker

struct SidebarTreeBuilderTests {
    @Test func buildsNestedProjectTreeFromConfiguredRoot() {
        let root = URL(fileURLWithPath: "/Workspace")
        let projects = [
            project(name: "Workspace", path: "/Workspace"),
            project(name: "Alpha", path: "/Workspace/Alpha"),
            project(name: "Nested", path: "/Workspace/Group/Nested"),
            project(name: "Deep", path: "/Workspace/Group/Subgroup/Deep")
        ]

        let tree = SidebarTreeBuilder.projectTree(projects: projects, roots: [root])

        #expect(tree.map(\.title) == ["Workspace"])
        let workspace = tree[0]
        #expect(workspace.project?.name == "Workspace")
        #expect(workspace.children.map(\.title) == ["Alpha", "Group"])
        let group = workspace.children[1]
        #expect(group.children.map(\.title) == ["Nested", "Subgroup"])
        #expect(group.children[1].children.map(\.title) == ["Deep"])
        #expect(group.children[1].children[0].project?.name == "Deep")
    }

    @Test func nestsItemsUnderBroadestConfiguredRoot() {
        let roots = [
            URL(fileURLWithPath: "/Workspace"),
            URL(fileURLWithPath: "/Workspace/Projects"),
            URL(fileURLWithPath: "/Workspace/Projects/Group")
        ]
        let projects = [
            project(name: "Root Project", path: "/Workspace/Projects"),
            project(name: "Nested", path: "/Workspace/Projects/Group/Nested")
        ]

        let tree = SidebarTreeBuilder.projectTree(projects: projects, roots: roots)

        #expect(tree.map(\.title) == ["Workspace"])
        let workspace = tree[0]
        #expect(workspace.children.map(\.title) == ["Projects"])
        #expect(workspace.children[0].project?.name == "Root Project")
        #expect(workspace.children[0].children.map(\.title) == ["Group"])
        #expect(workspace.children[0].children[0].children.map(\.title) == ["Nested"])
    }

    @Test func buildsNestedSkillTreeFromConfiguredRoot() {
        let root = URL(fileURLWithPath: "/Workspace")
        let skills = [
            skill(name: "Top Skill", path: "/Workspace/TopSkill"),
            skill(name: "Nested Skill", path: "/Workspace/Pack/NestedSkill"),
            skill(name: "Deep Skill", path: "/Workspace/Pack/More/DeepSkill")
        ]

        let tree = SidebarTreeBuilder.skillTree(skills: skills, roots: [root])

        #expect(tree.map(\.title) == ["Workspace"])
        let workspace = tree[0]
        #expect(workspace.children.map(\.title) == ["Pack", "TopSkill"])
        #expect(workspace.children[0].children.map(\.title) == ["More", "NestedSkill"])
        #expect(workspace.children[0].children[0].children.map(\.title) == ["DeepSkill"])
        #expect(workspace.children[0].children[0].children[0].skill?.name == "Deep Skill")
    }

    @Test func skillTreeHonorsSelectedFolderAndSkillSortModes() {
        let root = URL(fileURLWithPath: "/Workspace")
        let skills = [
            skill(name: "Alpha", path: "/Workspace/Small/Alpha"),
            skill(name: "Beta", path: "/Workspace/Large/Beta"),
            skill(name: "Zeta", path: "/Workspace/Large/Zeta")
        ]

        let tree = SidebarTreeBuilder.skillTree(
            skills: skills,
            roots: [root],
            folderSortMode: .countDescending,
            skillSortMode: .alphabeticalDescending
        )

        let workspace = tree[0]
        #expect(workspace.children.map(\.title) == ["Large", "Small"])
        #expect(workspace.children[0].children.map(\.skill?.name) == ["Zeta", "Beta"])
    }

    @Test func skillTreeHonorsPerDirectorySortOverrides() {
        let root = URL(fileURLWithPath: "/Workspace")
        let skills = [
            skill(name: "Alpha", path: "/Workspace/Pack/Alpha"),
            skill(name: "Zeta", path: "/Workspace/Pack/Zeta")
        ]

        let tree = SidebarTreeBuilder.skillTree(
            skills: skills,
            roots: [root],
            skillSortMode: .alphabeticalAscending,
            sortOverrides: [
                "folder:/Workspace/Pack": SidebarNodeSortConfiguration(skillSortMode: .alphabeticalDescending)
            ]
        )

        let pack = tree[0].children[0]
        #expect(pack.title == "Pack")
        #expect(pack.children.map(\.skill?.name) == ["Zeta", "Alpha"])
    }

    @Test func projectTreeHonorsSelectedSortMode() {
        let root = URL(fileURLWithPath: "/Workspace")
        let projects = [
            project(name: "Alpha", path: "/Workspace/Alpha"),
            project(name: "Zeta", path: "/Workspace/Zeta")
        ]

        let tree = SidebarTreeBuilder.projectTree(
            projects: projects,
            roots: [root],
            sortMode: .alphabeticalDescending
        )

        #expect(tree[0].children.map(\.project?.name) == ["Zeta", "Alpha"])
    }

    @Test func projectTreeHonorsPerDirectorySortOverrides() {
        let root = URL(fileURLWithPath: "/Workspace")
        let projects = [
            project(name: "Alpha", path: "/Workspace/Pack/Alpha"),
            project(name: "Zeta", path: "/Workspace/Pack/Zeta")
        ]

        let tree = SidebarTreeBuilder.projectTree(
            projects: projects,
            roots: [root],
            sortMode: .alphabeticalAscending,
            sortOverrides: [
                "folder:/Workspace/Pack": SidebarNodeSortConfiguration(itemSortMode: .alphabeticalDescending)
            ]
        )

        let pack = tree[0].children[0]
        #expect(pack.title == "Pack")
        #expect(pack.children.map(\.project?.name) == ["Zeta", "Alpha"])
    }

    @Test func projectTreeDirectorySortOverridesVisibleChildFolders() {
        let root = URL(fileURLWithPath: "/Workspace")
        let projects = [
            project(name: "Apple Tool", path: "/Workspace/Pack/apple/Apple Tool"),
            project(name: "Zebra Tool", path: "/Workspace/Pack/zebra/Zebra Tool")
        ]

        let tree = SidebarTreeBuilder.projectTree(
            projects: projects,
            roots: [root],
            sortMode: .alphabeticalAscending,
            sortOverrides: [
                "folder:/Workspace/Pack": SidebarNodeSortConfiguration(itemSortMode: .alphabeticalDescending)
            ]
        )

        let pack = tree[0].children[0]
        #expect(pack.title == "Pack")
        #expect(pack.children.map(\.title) == ["zebra", "apple"])
    }

    private func project(name: String, path: String) -> ProjectRecord {
        ProjectRecord(
            name: name,
            path: path,
            displayPath: path,
            signals: [.git],
            instructions: [],
            skills: [],
            automations: [],
            configs: [],
            mcps: [],
            projectFiles: [],
            warnings: [],
            createdAt: nil,
            modifiedAt: nil
        )
    }

    private func skill(name: String, path: String) -> SkillRecord {
        SkillRecord(
            id: "Other:\(path)",
            name: name,
            summary: "Fixture",
            platform: .other,
            source: .local(path: path),
            localPath: path,
            locationGroup: "/Workspace",
            tags: [],
            lastSeenAt: Date(),
            createdAt: nil,
            modifiedAt: nil
        )
    }
}
