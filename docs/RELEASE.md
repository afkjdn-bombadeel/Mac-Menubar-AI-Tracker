# Release Checklist

This project is designed for source-first open-source distribution. Local archives are useful for testing, but public binary releases should be signed and notarized before broad distribution.

## Local Archive

```bash
swift test
./script/package_release.sh 0.1.0
```

Expected artifacts:

- `dist/release/MacMenubarAITracker-0.1.0.zip`
- `dist/release/MacMenubarAITracker-0.1.0.zip.sha256`

## Public Binary Release

Before attaching binaries to a GitHub release:

- Sign with a Developer ID Application certificate instead of ad-hoc signing.
- Enable hardened runtime for the signed app.
- Notarize the archive with Apple.
- Staple the notarization ticket.
- Re-run a clean-machine launch check.

## GitHub Metadata

Suggested description:

```text
Local-first macOS menu bar tracker for Codex and Claude agent skills.
```

Suggested topics:

```text
macos, swift, swiftui, menubar, codex, claude, ai-agents, agent-skills, local-first, gplv3
```
