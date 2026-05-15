import SwiftUI

struct SkillDetailView: View {
    var skill: SkillRecord?
    @Environment(\.trackerAppearance) private var appearance

    var body: some View {
        Group {
            if let skill {
                VStack(alignment: .leading, spacing: 14) {
                    Text(skill.name)
                        .font(appearance.title)

                    Text(skill.summary)
                        .foregroundStyle(.secondary)

                    ResourceActions(path: skill.localPath)

                    LabeledContent("Platform", value: skill.platform.rawValue)
                    LabeledContent("Section", value: skill.locationGroup)

                    if let localPath = skill.localPath {
                        LabeledContent("Location", value: localPath)
                    }

                    if !skill.tags.isEmpty {
                        Text(skill.tags.joined(separator: ", "))
                            .font(appearance.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(20)
            } else {
                ContentUnavailableView(
                    "Select a Skill",
                    systemImage: "sparkles",
                    description: Text("Local skills will appear after scanning approved roots.")
                )
            }
        }
    }
}

struct ProjectDetailView: View {
    var project: ProjectRecord?
    @Environment(\.trackerAppearance) private var appearance

    var body: some View {
        Group {
            if let project {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(project.name)
                            .font(appearance.title)

                        Text(project.displayPath)
                            .foregroundStyle(.secondary)

                        ResourceActions(path: project.path)
                        ProjectSignalsView(project: project)
                        ProjectFileSection(title: "Warnings", systemImage: "exclamationmark.triangle", records: project.warnings.map {
                            DetailRecord(title: "Warning", subtitle: $0)
                        })
                        ProjectFileSection(title: "Instructions", systemImage: "text.book.closed", records: project.instructions.map {
                            DetailRecord(title: $0.name, subtitle: $0.path)
                        })
                        ProjectFileSection(title: "Skills", systemImage: "sparkles", records: project.skills.map {
                            DetailRecord(title: $0.name, subtitle: $0.localPath ?? "")
                        })
                        ProjectFileSection(title: "Automations", systemImage: "clock.arrow.circlepath", records: project.automations.map {
                            DetailRecord(title: "\($0.name)  \($0.status)", subtitle: "\($0.readableSchedule)\n\($0.kind) - \($0.path)")
                        })
                        ProjectFileSection(title: "Configs", systemImage: "gearshape", records: project.configs.map {
                            DetailRecord(title: $0.mayContainSecrets ? "\($0.kind)  Sensitive" : $0.kind, subtitle: $0.path)
                        })
                        ProjectFileSection(title: "Project Files", systemImage: "doc.text.magnifyingglass", records: project.projectFiles.map {
                            DetailRecord(title: "\($0.name)  \($0.kind)", subtitle: $0.path)
                        })
                        ProjectFileSection(title: "MCPs", systemImage: "point.3.connected.trianglepath.dotted", records: project.mcps.map {
                            DetailRecord(title: $0.name, subtitle: $0.detail)
                        })
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ContentUnavailableView(
                    "Select a Project",
                    systemImage: "folder",
                    description: Text("Detected agent-aware projects will appear here.")
                )
            }
        }
    }
}

struct ResourceActions: View {
    @AppStorage("defaultOpenApp") private var defaultOpenAppRaw = EditorChoice.textEdit.rawValue
    var path: String?

    private var defaultOpenApp: EditorChoice {
        EditorChoice(rawValue: defaultOpenAppRaw) ?? .textEdit
    }

    var body: some View {
        if let path, !path.isEmpty {
            HStack(spacing: 8) {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
                } label: {
                    Label("Finder", systemImage: "folder")
                }

                SplitOpenButton(path: path, defaultOpenApp: defaultOpenApp, defaultOpenAppRaw: $defaultOpenAppRaw)

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(path, forType: .string)
                } label: {
                    Label("Copy Path", systemImage: "doc.on.doc")
                }
            }
            .buttonStyle(.bordered)
        }
    }
}

struct SplitOpenButton: View {
    var path: String
    var defaultOpenApp: EditorChoice
    @Binding var defaultOpenAppRaw: String

    var body: some View {
        HStack(spacing: 0) {
            Button {
                open(path, with: defaultOpenApp)
            } label: {
                Image(systemName: defaultOpenApp.systemImage)
                    .frame(width: 26)
            }
            .buttonStyle(.plain)
            .help("Open in \(defaultOpenApp.label)")
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            Divider()
                .frame(height: 18)

            Menu {
                ForEach(EditorChoice.allCases) { choice in
                    Button {
                        defaultOpenAppRaw = choice.rawValue
                        open(path, with: choice)
                    } label: {
                        HStack {
                            Text(choice.label)
                            if choice == defaultOpenApp {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "chevron.down")
                    .frame(width: 18)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 6)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .fixedSize()
        .background(Color.secondary.opacity(0.18), in: RoundedRectangle(cornerRadius: 7))
    }

    private func open(_ path: String, with choice: EditorChoice) {
        let url = URL(fileURLWithPath: path)
        guard let appURL = choice.appURL else {
            NSWorkspace.shared.open(url)
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: configuration)
    }
}

enum EditorChoice: String, CaseIterable, Identifiable {
    case textEdit
    case vsCode
    case cursor
    case systemDefault

    var id: String { rawValue }

    var label: String {
        switch self {
        case .textEdit: return "TextEdit"
        case .vsCode: return "VS Code"
        case .cursor: return "Cursor"
        case .systemDefault: return "Default App"
        }
    }

    var systemImage: String {
        switch self {
        case .textEdit: return "doc.text"
        case .vsCode: return "chevron.left.forwardslash.chevron.right"
        case .cursor: return "cursorarrow"
        case .systemDefault: return "arrow.up.forward.app"
        }
    }

    var appURL: URL? {
        switch self {
        case .textEdit:
            return URL(fileURLWithPath: "/System/Applications/TextEdit.app")
        case .vsCode:
            return firstExistingApp([
                "/Applications/Visual Studio Code.app",
                "\(NSHomeDirectory())/Applications/Visual Studio Code.app"
            ])
        case .cursor:
            return firstExistingApp([
                "/Applications/Cursor.app",
                "\(NSHomeDirectory())/Applications/Cursor.app"
            ])
        case .systemDefault:
            return nil
        }
    }

    private func firstExistingApp(_ paths: [String]) -> URL? {
        paths.first { FileManager.default.fileExists(atPath: $0) }.map(URL.init(fileURLWithPath:))
    }
}

struct ProjectSignalsView: View {
    var project: ProjectRecord
    @Environment(\.trackerAppearance) private var appearance

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Signals")
                .font(appearance.headline)

            FlowLayout(items: project.signals.map(\.rawValue))
        }
    }
}

struct DetailRecord: Identifiable {
    var id: String { title + subtitle }
    var title: String
    var subtitle: String
}

struct ProjectFileSection: View {
    var title: String
    var systemImage: String
    var records: [DetailRecord]
    @Environment(\.trackerAppearance) private var appearance

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(appearance.headline)

            if records.isEmpty {
                Text("None found")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(records) { record in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(record.title)
                            .font(appearance.subheadlineSemibold)
                        Text(record.subtitle)
                            .font(appearance.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }
}
