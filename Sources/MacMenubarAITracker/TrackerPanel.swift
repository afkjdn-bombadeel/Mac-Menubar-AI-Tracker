import SwiftUI

private enum ProjectListAnchor {
    static let top = "project-list-top"
}

private struct VisibleSidebarNode: Identifiable {
    var id: String { node.id }
    var node: SidebarTreeNode
    var level: Int
}

struct TrackerPanel: View {
    @ObservedObject var store: SkillStore
    @ObservedObject var settings: TrackerSettings
    @Environment(\.trackerAppearance) private var appearance
    @AppStorage("expandedSkillGroups") private var expandedSkillGroupsStorage = ""
    @AppStorage("didCustomizeSkillGroups") private var didCustomizeSkillGroups = false
    @AppStorage("expandedProjectNodes") private var expandedProjectNodesStorage = ""
    @AppStorage("didCustomizeProjectNodes") private var didCustomizeProjectNodes = false
    @AppStorage("hiddenSkillIDs") private var hiddenSkillIDsStorage = ""
    @AppStorage("hiddenProjectIDs") private var hiddenProjectIDsStorage = ""
    @AppStorage("sidebarSortMode") private var sortModeRawValue = SidebarSortMode.alphabeticalAscending.rawValue
    @AppStorage("folderSortMode") private var folderSortModeRawValue = FolderSortMode.alphabeticalAscending.rawValue
    @AppStorage("skillSortMode") private var skillSortModeRawValue = SidebarSortMode.alphabeticalAscending.rawValue
    @State private var selectedTab: TrackerTab = .skills
    @State private var query = ""
    @State private var selectedSkillID: SkillRecord.ID?
    @State private var selectedProjectID: ProjectRecord.ID?
    @State private var expandedSkillGroups: Set<String> = []
    @State private var expandedProjectNodes: Set<String> = []
    @State private var projectFilter: ProjectFilter = .all
    @State private var sidebarWidth: CGFloat = 340

    private var sortMode: SidebarSortMode {
        SidebarSortMode(rawValue: sortModeRawValue) ?? .alphabeticalAscending
    }

    private var folderSortMode: FolderSortMode {
        FolderSortMode(rawValue: folderSortModeRawValue) ?? .alphabeticalAscending
    }

    private var skillSortMode: SidebarSortMode {
        SidebarSortMode(rawValue: skillSortModeRawValue) ?? .alphabeticalAscending
    }

    private var hiddenSkillIDs: Set<String> {
        decodeSet(hiddenSkillIDsStorage)
    }

    private var hiddenProjectIDs: Set<String> {
        decodeSet(hiddenProjectIDsStorage)
    }

    private var matchingSkills: [SkillRecord] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = trimmed.isEmpty ? store.skills : store.skills.filter { skill in
            skill.name.localizedCaseInsensitiveContains(trimmed)
            || skill.summary.localizedCaseInsensitiveContains(trimmed)
            || skill.tags.contains { $0.localizedCaseInsensitiveContains(trimmed) }
        }
        return filtered.sorted(by: skillSortMode.skillComparator)
    }

    private var filteredSkills: [SkillRecord] {
        matchingSkills.filter { !hiddenSkillIDs.contains($0.id) }
    }

    private var hiddenMatchingSkills: [SkillRecord] {
        matchingSkills.filter { hiddenSkillIDs.contains($0.id) }
    }

    private var selectedSkill: SkillRecord? {
        filteredSkills.first { $0.id == selectedSkillID } ?? filteredSkills.first
    }

    private var matchingProjects: [ProjectRecord] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return store.projects.filter { project in
            projectFilter.includes(project)
                && (trimmed.isEmpty
                    || project.name.localizedCaseInsensitiveContains(trimmed)
                    || project.displayPath.localizedCaseInsensitiveContains(trimmed)
                    || project.signals.contains { $0.rawValue.localizedCaseInsensitiveContains(trimmed) }
                    || project.instructions.contains { $0.name.localizedCaseInsensitiveContains(trimmed) }
                    || project.automations.contains { $0.name.localizedCaseInsensitiveContains(trimmed) })
        }.sorted(by: sortMode.projectComparator)
    }

    private var filteredProjects: [ProjectRecord] {
        matchingProjects.filter { !hiddenProjectIDs.contains($0.id) }
    }

    private var hiddenMatchingProjects: [ProjectRecord] {
        matchingProjects.filter { hiddenProjectIDs.contains($0.id) }
    }

    private var selectedProject: ProjectRecord? {
        filteredProjects.first { $0.id == selectedProjectID } ?? filteredProjects.first
    }

    private var searchPlaceholder: String {
        switch selectedTab {
        case .skills:
            return "Search skills"
        case .projects:
            return "Search projects"
        }
    }

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var skillTree: [SidebarTreeNode] {
        SidebarTreeBuilder.skillTree(skills: filteredSkills, roots: settings.scanRoots)
    }

    private var projectTree: [SidebarTreeNode] {
        SidebarTreeBuilder.projectTree(projects: filteredProjects, roots: settings.scanRoots)
    }

    private var visibleProjectNodes: [VisibleSidebarNode] {
        flattenedProjectNodes(projectTree)
    }

    private var skillExpansionBinding: Binding<Set<String>> {
        Binding {
            expandedSkillGroups
        } set: { newValue in
            expandedSkillGroups = newValue
            didCustomizeSkillGroups = true
            expandedSkillGroupsStorage = encodeSet(newValue)
        }
    }

    private var projectExpansionBinding: Binding<Set<String>> {
        Binding {
            expandedProjectNodes
        } set: { newValue in
            expandedProjectNodes = newValue
            didCustomizeProjectNodes = true
            expandedProjectNodesStorage = encodeSet(newValue)
        }
    }

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                sidebar
                    .frame(width: clampedSidebarWidth(totalWidth: proxy.size.width))

                Divider()
                    .frame(width: 8)
                    .overlay(ResizeCursorView())
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(coordinateSpace: .named("trackerSplit"))
                            .onChanged { value in
                                sidebarWidth = clampedSidebarWidth(
                                    totalWidth: proxy.size.width,
                                    proposedWidth: value.location.x
                                )
                            }
                    )
                    .help("Drag to resize")

                detailPane
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .coordinateSpace(name: "trackerSplit")
            .font(settings.interfaceFont)
            .foregroundStyle(settings.fontColor)
            .background(settings.backgroundColor.opacity(settings.panelOpacity))
            .environment(\.trackerAppearance, TrackerAppearance(fontName: settings.fontName, fontSize: settings.fontSize))
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            tabPicker
            sidebarControlBar
            toolbar
            if selectedTab == .projects {
                projectFilterBar
            }
            switch selectedTab {
            case .skills:
                skillList
            case .projects:
                projectList
            }
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        switch selectedTab {
        case .skills:
            SkillDetailView(skill: selectedSkill)
        case .projects:
            ProjectDetailView(project: selectedProject)
        }
    }

    private func clampedSidebarWidth(totalWidth: CGFloat, proposedWidth: CGFloat? = nil) -> CGFloat {
        let maximum = min(560, max(260, totalWidth - 360))
        return min(max(proposedWidth ?? sidebarWidth, 260), maximum)
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(searchPlaceholder, text: $query)
                .textFieldStyle(.plain)
                .lineLimit(1)

            if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    moveSearchSelection(direction: -1)
                } label: {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.borderless)
                .help("Previous result")

                Button {
                    moveSearchSelection(direction: 1)
                } label: {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.borderless)
                .help("Next result")
            }

            Button {
                Task { await store.refresh(roots: settings.scanRoots) }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh local skills")
            .disabled(store.isRefreshing)
        }
        .padding(12)
        .background(.bar)
    }

    private var tabPicker: some View {
        HStack(spacing: 10) {
            Spacer(minLength: 36)

            Picker("", selection: $selectedTab) {
                ForEach(TrackerTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 180)

            Spacer()

            Button {
                SettingsWindowController.shared.show(settings: settings) {
                    Task { await store.refresh(roots: settings.scanRoots) }
                }
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Settings")
        }
        .padding(12)
    }

    private var sidebarControlBar: some View {
        HStack(spacing: 8) {
            Button {
                expandAll()
            } label: {
                Label("Expand All", systemImage: "chevron.down.square")
            }
            .buttonStyle(.borderless)
            .help(selectedTab == .skills ? "Expand all skill folders" : "Expand all project folders")

            Button {
                collapseAll()
            } label: {
                Label("Collapse All", systemImage: "chevron.up.square")
            }
            .buttonStyle(.borderless)
            .help(selectedTab == .skills ? "Collapse all skill folders" : "Collapse all project folders")

            Spacer()

            Menu {
                if selectedTab == .skills {
                    ForEach(FolderSortMode.allCases) { mode in
                        Button {
                            folderSortModeRawValue = mode.rawValue
                        } label: {
                            HStack {
                                Text(mode.title)
                                if folderSortMode == mode {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } else {
                    ForEach(SidebarSortMode.allCases) { mode in
                        Button {
                            sortModeRawValue = mode.rawValue
                        } label: {
                            HStack {
                                Text(mode.title)
                                if sortMode == mode {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            } label: {
                Label(selectedTab == .skills ? "Sort Folders" : "Sort", systemImage: "arrow.up.arrow.down")
            }
            .menuStyle(.borderlessButton)
            .help(selectedTab == .skills ? "Sort skill folders" : "Sort projects")
        }
        .font(appearance.captionSemibold)
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }

    private var projectFilterBar: some View {
        ProjectFilterScrollBar(selection: $projectFilter)
            .frame(height: 46)
        .padding(.bottom, 8)
        .background(.bar)
    }

    private var skillList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2, pinnedViews: []) {
                ForEach(skillTree) { node in
                    SkillTreeNodeView(
                        node: node,
                        level: 0,
                        forceExpanded: isSearching,
                        autoExpandTopLevel: !didCustomizeSkillGroups,
                        expandedIDs: skillExpansionBinding,
                        selectedSkillID: $selectedSkillID,
                        hideSkill: { hideSkill($0) }
                    )
                }

                if !hiddenMatchingSkills.isEmpty {
                    HiddenItemsSection(
                        title: "Hidden Skills",
                        items: hiddenMatchingSkills.map { ($0.id, $0.name) },
                        unhide: unhideSkill(id:)
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .onAppear {
            if didCustomizeSkillGroups {
                expandedSkillGroups = decodeSet(expandedSkillGroupsStorage)
            }
        }
        .overlay {
            if filteredSkills.isEmpty {
                ContentUnavailableView(
                    "No Local Skills",
                    systemImage: "folder.badge.questionmark",
                    description: Text("Add skill directories in Settings, then refresh.")
                )
            }
        }
    }

    private var skillSortMenu: AnyView {
        AnyView(
        Menu {
            ForEach(SidebarSortMode.allCases) { mode in
                Button {
                    skillSortModeRawValue = mode.rawValue
                } label: {
                    HStack {
                        Text(mode.title)
                        if skillSortMode == mode {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 24)
        .help("Sort skills in folder")
        )
    }

    private var projectList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    Color.clear
                        .frame(height: 0)
                        .id(ProjectListAnchor.top)

                    ForEach(visibleProjectNodes) { visibleNode in
                        ProjectTreeRowView(
                            node: visibleNode.node,
                            level: visibleNode.level,
                            isExpanded: isProjectNodeExpanded(visibleNode.node, level: visibleNode.level),
                            toggle: { toggleProjectNode(visibleNode.node.id) },
                            selectedProjectID: $selectedProjectID,
                            hideProject: { hideProject($0) }
                        )
                    }

                    if !hiddenMatchingProjects.isEmpty {
                        HiddenItemsSection(
                            title: "Hidden Projects",
                            items: hiddenMatchingProjects.map { ($0.id, $0.name) },
                            unhide: unhideProject(id:)
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .onAppear {
                if didCustomizeProjectNodes {
                    expandedProjectNodes = decodeSet(expandedProjectNodesStorage)
                }
            }
            .onChange(of: projectFilter) { _, _ in
                withAnimation(.easeOut(duration: 0.16)) {
                    proxy.scrollTo(ProjectListAnchor.top, anchor: .top)
                }
            }
            .overlay {
                if filteredProjects.isEmpty {
                    ContentUnavailableView(
                        "No Projects",
                        systemImage: "folder.badge.questionmark",
                        description: Text("Projects appear when folders contain agent instructions, configs, skills, git, or automations.")
                    )
                }
            }
        }
    }

    private func collapseAll() {
        switch selectedTab {
        case .skills:
            expandedSkillGroups.removeAll()
            didCustomizeSkillGroups = true
            expandedSkillGroupsStorage = ""
        case .projects:
            expandedProjectNodes.removeAll()
            didCustomizeProjectNodes = true
            expandedProjectNodesStorage = ""
        }
    }

    private func expandAll() {
        switch selectedTab {
        case .skills:
            let ids = collectExpandableIDs(skillTree)
            expandedSkillGroups = ids
            didCustomizeSkillGroups = true
            expandedSkillGroupsStorage = encodeSet(ids)
        case .projects:
            let ids = collectExpandableIDs(projectTree)
            expandedProjectNodes = ids
            didCustomizeProjectNodes = true
            expandedProjectNodesStorage = encodeSet(ids)
        }
    }

    private func collectExpandableIDs(_ nodes: [SidebarTreeNode]) -> Set<String> {
        nodes.reduce(into: Set<String>()) { result, node in
            if !node.children.isEmpty {
                result.insert(node.id)
            }
            result.formUnion(collectExpandableIDs(node.children))
        }
    }

    private func flattenedProjectNodes(_ nodes: [SidebarTreeNode], level: Int = 0) -> [VisibleSidebarNode] {
        nodes.flatMap { node -> [VisibleSidebarNode] in
            var result = [VisibleSidebarNode(node: node, level: level)]
            if isProjectNodeExpanded(node, level: level) {
                result.append(contentsOf: flattenedProjectNodes(node.children, level: level + 1))
            }
            return result
        }
    }

    private func isProjectNodeExpanded(_ node: SidebarTreeNode, level: Int) -> Bool {
        isSearching || expandedProjectNodes.contains(node.id) || (!didCustomizeProjectNodes && level == 0)
    }

    private func toggleProjectNode(_ id: String) {
        guard !isSearching else { return }
        if expandedProjectNodes.contains(id) {
            expandedProjectNodes.remove(id)
        } else {
            expandedProjectNodes.insert(id)
        }
        didCustomizeProjectNodes = true
        expandedProjectNodesStorage = encodeSet(expandedProjectNodes)
    }

    private func hideSkill(_ skill: SkillRecord) {
        var ids = hiddenSkillIDs
        ids.insert(skill.id)
        hiddenSkillIDsStorage = encodeSet(ids)
        if selectedSkillID == skill.id {
            selectedSkillID = filteredSkills.first { $0.id != skill.id }?.id
        }
    }

    private func unhideSkill(id: String) {
        var ids = hiddenSkillIDs
        ids.remove(id)
        hiddenSkillIDsStorage = encodeSet(ids)
    }

    private func hideProject(_ project: ProjectRecord) {
        var ids = hiddenProjectIDs
        ids.insert(project.id)
        hiddenProjectIDsStorage = encodeSet(ids)
        if selectedProjectID == project.id {
            selectedProjectID = filteredProjects.first { $0.id != project.id }?.id
        }
    }

    private func unhideProject(id: String) {
        var ids = hiddenProjectIDs
        ids.remove(id)
        hiddenProjectIDsStorage = encodeSet(ids)
    }

    private func moveSearchSelection(direction: Int) {
        switch selectedTab {
        case .skills:
            let ids = filteredSkills.map(\.id)
            guard !ids.isEmpty else { return }
            selectedSkillID = nextID(in: ids, current: selectedSkillID, direction: direction)
        case .projects:
            let ids = filteredProjects.map(\.id)
            guard !ids.isEmpty else { return }
            selectedProjectID = nextID(in: ids, current: selectedProjectID, direction: direction)
        }
    }

    private func nextID(in ids: [String], current: String?, direction: Int) -> String {
        guard let current, let index = ids.firstIndex(of: current) else {
            return direction < 0 ? ids.last! : ids.first!
        }
        let nextIndex = (index + direction + ids.count) % ids.count
        return ids[nextIndex]
    }

    private func decodeSet(_ value: String) -> Set<String> {
        Set(value.split(separator: "\n").map(String.init).filter { !$0.isEmpty })
    }

    private func encodeSet(_ values: Set<String>) -> String {
        values.sorted().joined(separator: "\n")
    }
}
