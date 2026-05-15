import SwiftUI

struct ResizeCursorView: NSViewRepresentable {
    func makeNSView(context: Context) -> ResizeCursorNSView {
        ResizeCursorNSView()
    }

    func updateNSView(_ nsView: ResizeCursorNSView, context: Context) {
        nsView.updateTrackingAreas()
    }
}

final class ResizeCursorNSView: NSView {
    private var trackingArea: NSTrackingArea?
    private var didPushCursor = false

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.resizeLeftRight.push()
        didPushCursor = true
    }

    override func mouseExited(with event: NSEvent) {
        if didPushCursor {
            NSCursor.pop()
            didPushCursor = false
        }
    }

    deinit {
        if didPushCursor {
            NSCursor.pop()
        }
    }
}

struct ProjectFilterScrollBar: NSViewRepresentable {
    @Binding var selection: ProjectFilter

    func makeNSView(context: Context) -> NSScrollView {
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.scrollerStyle = .legacy
        scrollView.horizontalScroller?.controlSize = .small
        scrollView.borderType = .noBorder
        scrollView.documentView = hostingView

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            hostingView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: scrollView.contentView.bottomAnchor),
            hostingView.widthAnchor.constraint(equalToConstant: ProjectFilter.totalBarWidth),
            hostingView.heightAnchor.constraint(equalTo: scrollView.contentView.heightAnchor)
        ])

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        if let hostingView = scrollView.documentView as? NSHostingView<ProjectFilterBarContent> {
            hostingView.rootView = contentView
        }
    }

    private var contentView: ProjectFilterBarContent {
        ProjectFilterBarContent(selection: $selection)
    }
}

struct ProjectFilterBarContent: View {
    @Binding var selection: ProjectFilter
    @Environment(\.trackerAppearance) private var appearance

    var body: some View {
        HStack(spacing: 6) {
            ForEach(ProjectFilter.allCases) { filter in
                Button {
                    selection = filter
                } label: {
                    Text(filter.rawValue)
                        .font(appearance.captionSemibold)
                        .lineLimit(1)
                        .frame(width: filter.buttonWidth, height: 28)
                        .background(selection == filter ? Color.accentColor.opacity(0.32) : Color.secondary.opacity(0.18), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 2)
        .padding(.bottom, 10)
    }
}

struct SkillGroupHeader: View {
    var title: String
    var count: Int
    var isExpanded: Bool
    var action: () -> Void
    var sort: () -> AnyView
    @Environment(\.trackerAppearance) private var appearance

    var body: some View {
        HStack(spacing: 6) {
            Button(action: action) {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(appearance.captionSemibold)
                        .frame(width: 12)

                    Text(title)
                        .font(appearance.subheadlineSemibold)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: 8)

                    Text("\(count)")
                        .font(appearance.captionSemibold)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                sort()
                    .frame(width: 24)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
}

struct SidebarTreeFolderRow: View {
    var title: String
    var count: Int
    var level: Int
    var isExpanded: Bool
    var toggle: () -> Void
    var sortMenu: (() -> AnyView)? = nil
    @Environment(\.trackerAppearance) private var appearance
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 6) {
            Spacer()
                .frame(width: CGFloat(level) * 14)

            Button(action: toggle) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(appearance.captionSemibold)
                    .frame(width: 12)
            }
            .buttonStyle(.plain)
            .help(isExpanded ? "Collapse" : "Expand")

            Image(systemName: isExpanded ? "folder.fill" : "folder")
                .font(appearance.captionSemibold)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Text(title)
                .font(appearance.subheadlineSemibold)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .contentShape(Rectangle())
                .onTapGesture(perform: toggle)

            if let sortMenu {
                sortMenu()
                    .frame(width: 22)
                    .opacity(isHovering ? 1 : 0.01)
            }

            Spacer(minLength: 8)

            Text("\(count)")
                .font(appearance.captionSemibold)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .onHover { isHovering = $0 }
    }
}

struct DirectorySortMenu: View {
    var configuration: SidebarNodeSortConfiguration?
    var defaultFolderSortMode: FolderSortMode?
    var defaultItemSortMode: SidebarSortMode
    var itemSectionTitle: String
    var setConfiguration: (SidebarNodeSortConfiguration?) -> Void

    var body: some View {
        Menu {
            Button("Use Global Sort") {
                setConfiguration(nil)
            }

            if let defaultFolderSortMode {
                Section("Folders") {
                    ForEach(FolderSortMode.allCases) { mode in
                        Button {
                            var updated = configuration ?? SidebarNodeSortConfiguration()
                            updated.folderSortMode = mode
                            setConfiguration(updated)
                        } label: {
                            HStack {
                                Text(mode.title)
                                if (configuration?.folderSortMode ?? defaultFolderSortMode) == mode {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }

            Section(itemSectionTitle) {
                ForEach(SidebarSortMode.allCases) { mode in
                    Button {
                        var updated = configuration ?? SidebarNodeSortConfiguration()
                        if defaultFolderSortMode == nil {
                            updated.itemSortMode = mode
                        } else {
                            updated.skillSortMode = mode
                        }
                        setConfiguration(updated)
                    } label: {
                        HStack {
                            Text(mode.title)
                            if activeItemSortMode == mode {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .help("Sort this folder")
    }

    private var activeItemSortMode: SidebarSortMode {
        if defaultFolderSortMode == nil {
            return configuration?.itemSortMode ?? defaultItemSortMode
        }
        return configuration?.skillSortMode ?? defaultItemSortMode
    }
}

struct SkillTreeNodeView: View {
    var node: SidebarTreeNode
    var level: Int
    var forceExpanded: Bool
    var autoExpandTopLevel: Bool
    @Binding var expandedIDs: Set<String>
    @Binding var selectedSkillID: SkillRecord.ID?
    var hideSkill: (SkillRecord) -> Void
    var sortConfiguration: (String) -> SidebarNodeSortConfiguration?
    var setSortConfiguration: (String, SidebarNodeSortConfiguration?) -> Void
    var defaultFolderSortMode: FolderSortMode
    var defaultSkillSortMode: SidebarSortMode

    private var isExpanded: Bool {
        forceExpanded || expandedIDs.contains(node.id) || (autoExpandTopLevel && level == 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let skill = node.skill {
                HStack(spacing: 6) {
                    Spacer()
                        .frame(width: CGFloat(level) * 14)

                    disclosureButton

                    SkillRow(skill: skill, isSelected: selectedSkillID == skill.id)

                    Button {
                        hideSkill(skill)
                    } label: {
                        Image(systemName: "eye.slash")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Hide skill")
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedSkillID = skill.id
                }
            } else {
                SidebarTreeFolderRow(
                    title: node.title,
                    count: node.itemCount,
                    level: level,
                    isExpanded: isExpanded,
                    toggle: toggle,
                    sortMenu: folderSortMenu
                )
            }

            if isExpanded {
                ForEach(node.children) { child in
                    SkillTreeNodeView(
                        node: child,
                        level: level + 1,
                        forceExpanded: forceExpanded,
                        autoExpandTopLevel: autoExpandTopLevel,
                        expandedIDs: $expandedIDs,
                        selectedSkillID: $selectedSkillID,
                        hideSkill: hideSkill,
                        sortConfiguration: sortConfiguration,
                        setSortConfiguration: setSortConfiguration,
                        defaultFolderSortMode: defaultFolderSortMode,
                        defaultSkillSortMode: defaultSkillSortMode
                    )
                }
            }
        }
    }

    private func folderSortMenu() -> AnyView {
        AnyView(
            DirectorySortMenu(
                configuration: sortConfiguration(node.id),
                defaultFolderSortMode: defaultFolderSortMode,
                defaultItemSortMode: defaultSkillSortMode,
                itemSectionTitle: "Skills",
                setConfiguration: { setSortConfiguration(node.id, $0) }
            )
        )
    }

    @ViewBuilder
    private var disclosureButton: some View {
        if node.children.isEmpty {
            Spacer()
                .frame(width: 12)
        } else {
            Button(action: toggle) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .frame(width: 12)
            }
            .buttonStyle(.plain)
            .help(isExpanded ? "Collapse" : "Expand")
        }
    }

    private func toggle() {
        guard !forceExpanded else { return }
        if expandedIDs.contains(node.id) {
            expandedIDs.remove(node.id)
        } else {
            expandedIDs.insert(node.id)
        }
    }
}

struct ProjectTreeNodeView: View {
    var node: SidebarTreeNode
    var level: Int
    var forceExpanded: Bool
    var autoExpandTopLevel: Bool
    @Binding var expandedIDs: Set<String>
    @Binding var selectedProjectID: ProjectRecord.ID?
    var hideProject: (ProjectRecord) -> Void

    private var isExpanded: Bool {
        forceExpanded || expandedIDs.contains(node.id) || (autoExpandTopLevel && level == 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let project = node.project {
                HStack(spacing: 6) {
                    Spacer()
                        .frame(width: CGFloat(level) * 14)

                    disclosureButton

                    ProjectRow(project: project, isSelected: selectedProjectID == project.id)

                    Button {
                        hideProject(project)
                    } label: {
                        Image(systemName: "eye.slash")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Hide project")
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedProjectID = project.id
                }
            } else {
                SidebarTreeFolderRow(
                    title: node.title,
                    count: node.itemCount,
                    level: level,
                    isExpanded: isExpanded,
                    toggle: toggle
                )
            }

            if isExpanded {
                ForEach(node.children) { child in
                    ProjectTreeNodeView(
                        node: child,
                        level: level + 1,
                        forceExpanded: forceExpanded,
                        autoExpandTopLevel: autoExpandTopLevel,
                        expandedIDs: $expandedIDs,
                        selectedProjectID: $selectedProjectID,
                        hideProject: hideProject
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var disclosureButton: some View {
        if node.children.isEmpty {
            Spacer()
                .frame(width: 12)
        } else {
            Button(action: toggle) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .frame(width: 12)
            }
            .buttonStyle(.plain)
            .help(isExpanded ? "Collapse" : "Expand")
        }
    }

    private func toggle() {
        guard !forceExpanded else { return }
        if expandedIDs.contains(node.id) {
            expandedIDs.remove(node.id)
        } else {
            expandedIDs.insert(node.id)
        }
    }
}

struct ProjectTreeRowView: View {
    var node: SidebarTreeNode
    var level: Int
    var isExpanded: Bool
    var toggle: () -> Void
    @Binding var selectedProjectID: ProjectRecord.ID?
    var hideProject: (ProjectRecord) -> Void
    var sortConfiguration: (String) -> SidebarNodeSortConfiguration?
    var setSortConfiguration: (String, SidebarNodeSortConfiguration?) -> Void
    var defaultSortMode: SidebarSortMode

    var body: some View {
        if let project = node.project {
            HStack(spacing: 6) {
                Spacer()
                    .frame(width: CGFloat(level) * 14)

                disclosureButton

                ProjectRow(project: project, isSelected: selectedProjectID == project.id)

                Button {
                    hideProject(project)
                } label: {
                    Image(systemName: "eye.slash")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Hide project")
            }
            .contentShape(Rectangle())
            .onTapGesture {
                selectedProjectID = project.id
            }
        } else {
            SidebarTreeFolderRow(
                title: node.title,
                count: node.itemCount,
                level: level,
                isExpanded: isExpanded,
                toggle: toggle,
                sortMenu: folderSortMenu
            )
        }
    }

    private func folderSortMenu() -> AnyView {
        AnyView(
            DirectorySortMenu(
                configuration: sortConfiguration(node.id),
                defaultFolderSortMode: nil,
                defaultItemSortMode: defaultSortMode,
                itemSectionTitle: "Contents",
                setConfiguration: { setSortConfiguration(node.id, $0) }
            )
        )
    }

    @ViewBuilder
    private var disclosureButton: some View {
        if node.children.isEmpty {
            Spacer()
                .frame(width: 12)
        } else {
            Button(action: toggle) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .frame(width: 12)
            }
            .buttonStyle(.plain)
            .help(isExpanded ? "Collapse" : "Expand")
        }
    }
}

struct SkillRow: View {
    var skill: SkillRecord
    var isSelected: Bool
    @Environment(\.trackerAppearance) private var appearance

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(skill.name)
                    .font(appearance.subheadlineSemibold)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer()

                Text(skill.platform.rawValue)
                    .font(appearance.caption)
                    .foregroundStyle(.secondary)
            }

            Text(skill.summary)
                .font(appearance.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            Text(dateSummary)
                .font(appearance.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.accentColor.opacity(0.22) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
    }

    private var dateSummary: String {
        DateSummaryFormatter.summary(createdAt: skill.createdAt, modifiedAt: skill.modifiedAt)
    }
}

struct ProjectRow: View {
    var project: ProjectRecord
    var isSelected: Bool
    @Environment(\.trackerAppearance) private var appearance

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                Text(project.name)
                    .font(appearance.subheadlineSemibold)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 8)

                if !project.warnings.isEmpty {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(appearance.caption)
                        .foregroundStyle(.yellow)
                        .help(project.warnings.joined(separator: "\n"))
                }
            }

            Text(project.displayPath)
                .font(appearance.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            Text(project.signals.map(\.rawValue).joined(separator: "  "))
                .font(appearance.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Text(dateSummary)
                .font(appearance.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.accentColor.opacity(0.22) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
    }

    private var dateSummary: String {
        DateSummaryFormatter.summary(createdAt: project.createdAt, modifiedAt: project.modifiedAt)
    }
}

struct HiddenItemsSection: View {
    var title: String
    var items: [(id: String, name: String)]
    var unhide: (String) -> Void
    @Environment(\.trackerAppearance) private var appearance

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(appearance.captionSemibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.top, 8)

            ForEach(items, id: \.id) { item in
                HStack(spacing: 8) {
                    Text(item.name)
                        .font(appearance.captionSemibold)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer()

                    Button {
                        unhide(item.id)
                    } label: {
                        Image(systemName: "eye")
                    }
                    .buttonStyle(.borderless)
                    .help("Unhide")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }
}

struct FlowLayout: View {
    var items: [String]
    @Environment(\.trackerAppearance) private var appearance

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(appearance.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
            }
        }
    }
}
