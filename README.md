# Mac Menubar AI Tracker

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

A local-first macOS menu bar app for browsing agent skills and nearby agent-aware projects. It scans only configured local directories, reads `SKILL.md` metadata, and presents a compact searchable tracker from the menu bar.

The app is intentionally small: no telemetry, no network refresh, no installers, no background service, and no automatic broad home-directory scan.

## What It Does

- Lists local Codex, Claude, and user-configured skills from `SKILL.md` files.
- Parses skill `name`, `description`, and `tags` from simple markdown frontmatter.
- Groups skills by scan location and supports search, sorting, hide/unhide, and detail views.
- Optionally scans user-added project roots for agent signals such as `AGENTS.md`, `CLAUDE.md`, `.codex`, `.claude`, package files, local skills, and Codex automation references.
- Lets users open a selected skill or project in Finder, TextEdit, VS Code, Cursor, or the system default app.
- Provides local appearance and scan-directory settings through the menu bar UI.

## Repository Contents

- `Package.swift` - SwiftPM package for the macOS 14+ menu bar executable and tests.
- `Sources/MacMenubarAITracker/MacMenubarAITrackerApp.swift` - app entry point and `MenuBarExtra` setup.
- `Sources/MacMenubarAITracker/Models.swift` - skill, project, automation, config, and MCP summary models.
- `Sources/MacMenubarAITracker/SkillParser.swift` - lightweight `SKILL.md` metadata parser.
- `Sources/MacMenubarAITracker/InstalledSkillsScanner.swift` - local skill scanner for configured roots.
- `Sources/MacMenubarAITracker/WorkspaceScanner.swift` - project, automation, config, and MCP summary scanner.
- `Sources/MacMenubarAITracker/SkillStore.swift` - observable store that refreshes scanner snapshots off the main actor.
- `Sources/MacMenubarAITracker/TrackerSettings.swift` - persisted scan-directory and appearance settings.
- `Sources/MacMenubarAITracker/TrackerPanel.swift` - SwiftUI menu bar panel coordinator and app-opening actions.
- `Sources/MacMenubarAITracker/TrackerPanelComponents.swift` - reusable sidebar, filter, cursor, and tree row views.
- `Sources/MacMenubarAITracker/TrackerDetailViews.swift` - selected skill and project detail panes.
- `Sources/MacMenubarAITracker/SettingsView.swift` - scan-directory and appearance settings window.
- `Sources/MacMenubarAITracker/SidebarTreeBuilder.swift` - nested sidebar tree construction for skills and projects.
- `Tests/MacMenubarAITrackerTests/` - parser, scanner, and settings tests.
- `script/build_and_run.sh` - project-local build, bundle, launch, and `--verify` script.
- `script/package_release.sh` - local release archive builder for a zipped app bundle and checksum.
- `.codex/environments/environment.toml` - Codex app run action pointing at the build script.

## Build, Test, And Run

Requirements:

- macOS 14 or newer
- Xcode command line tools with Swift 6 support

Commands:

```bash
swift test
swift build
./script/build_and_run.sh --verify
```

The build script creates `dist/MacMenubarAITracker.app`, launches it as a proper app bundle, and verifies the process is running when `--verify` is passed.

## Local Release Build

To build a local distributable archive:

```bash
./script/package_release.sh 0.1.0
```

The package script creates `dist/release/MacMenubarAITracker-<version>.zip` and a matching `.sha256` checksum. The app is ad-hoc signed for local archive validation. Public binary releases should still be signed with a Developer ID certificate and notarized before distribution.

## Privacy And Safety Model

- Default scan roots are `~/.codex/skills` and `~/.claude/skills` when those folders exist.
- Additional roots are user-selected in Settings.
- The scanner skips common generated and dependency directories such as `.git`, `.build`, `node_modules`, `DerivedData`, `dist`, `target`, and `vendor`.
- The app does not read secret-bearing config contents. It only marks common secret-bearing files, such as `.env`, as present.
- MCP config summaries hide values and report only high-level shape.
- The app does not make network calls, install skills, run scripts, create login items, or create background services.

## License

Mac Menubar AI Tracker is licensed under the GNU General Public License v3.0. See `LICENSE` for the full license text. Project attribution can use `@tombombadeel`; do not add a personal name.

## GitHub Metadata

Suggested repository description:

```text
Local-first macOS menu bar tracker for Codex and Claude agent skills.
```

Suggested topics:

```text
macos, swift, swiftui, menubar, codex, claude, ai-agents, agent-skills, local-first, gplv3
```

## Rebuild From Scratch With A Coding Agent

Use this prompt when you want Codex or another coding agent to recreate the app from scratch instead of cloning or installing this repository:

```text
Build a clean SwiftPM macOS 14+ menu bar app named MacMenubarAITracker.

Product requirements:
- Use SwiftUI MenuBarExtra with a window-style menu bar panel titled "AI Skills" and a sparkles system image.
- Keep the app local-first. Do not add telemetry, networking, installers, login items, launch agents, cron jobs, or background services.
- Default skill roots should be ~/.codex/skills and ~/.claude/skills when they exist.
- Let users add/remove scan directories in a Settings window. Persist settings in UserDefaults.
- Scan configured roots for SKILL.md files, skipping generated/dependency directories: .git, .build, node_modules, DerivedData, dist, target, vendor, Pods, and .svn.
- Parse SKILL.md frontmatter fields name, description, and tags. If frontmatter is absent, fall back to the first "# " heading, then the folder name, and use the first body paragraph as the summary.
- Show a searchable Skills tab with grouped folders, sorting, hide/unhide, and a detail pane with platform, section, tags, and local path.
- Add an optional Projects tab that only scans user-configured non-skill roots and Codex automation cwd references. Summarize agent-aware signals such as AGENTS.md, CLAUDE.md, .codex, .claude, Package.swift, package.json, Xcode projects, local skills, automations, safe MCP config presence, and secret-bearing config presence without reading secrets.
- Provide buttons to reveal selected paths in Finder and open them in TextEdit, VS Code, Cursor, or the system default app.
- Add simple appearance settings for opacity, background color, font color, font family, and font size.

Implementation requirements:
- Use only Foundation, SwiftUI, and AppKit. Do not add third-party packages.
- License the rebuilt project under GNU GPLv3 and include the full GPLv3 text in LICENSE.
- Use @tombombadeel for project attribution. Do not add a personal name.
- Keep models Codable and Hashable where practical.
- Run scanner work off the main actor and publish snapshots through an ObservableObject store.
- Keep config previews value-redacted and never print or display secrets.
- Include Swift Testing tests for SKILL.md parsing, configured-root scanning, and settings persistence.
- Add script/build_and_run.sh that kills an existing app process, runs swift build, stages dist/MacMenubarAITracker.app with a minimal Info.plist, launches it with /usr/bin/open -n, and supports --verify with pgrep.
- Add a concise README documenting features, repository contents, privacy/safety behavior, and build/test/run commands.

Verification:
- Run swift test.
- Run swift build.
- Run ./script/build_and_run.sh --verify.
- Launch the app and manually verify the menu bar panel opens, search works, Settings opens, directory controls do not crash, and the UI remains local-only.
```
