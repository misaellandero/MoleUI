# Mole CLI To UI Parity

This document maps the Mole terminal experience to the native macOS UI. The rule is simple: do not show a primary UI action until it is backed by a real Mole command bridge, preview state, cancellation path, and result handling.

Sources:

- Mole README command surface: https://github.com/tw93/Mole/blob/main/README.md
- Local source-tree help: `./mole --help`

## Product Rule

- The main UI should not use the word "Mole" as a repeated feature label. The app can show the bundled runtime version in Settings or Diagnostics, but user-facing modules should read like native system-care features.
- Every destructive command starts with preview or dry-run.
- Actual deletion must go through the bundled CLI runtime and Mole safety helpers.
- Commands that are setup or lifecycle tools belong in Settings, Diagnostics, or Advanced, not as large homepage cards.
- If a command only has terminal output today, add or stabilize JSON before building a polished UI around it.

## Command Map

| CLI command | UI module | UI status | Tracking | Notes |
| --- | --- | --- | --- | --- |
| `mo clean` | Clean | In progress | #5, #9 | Deep cleanup, app leftovers, category preview, confirmation, history update. |
| `mo clean --dry-run --json` | Clean preview | In progress | #4, #5 | Primary source for reclaimable-space cards and cleanup checklist. |
| `mo clean --whitelist` | Settings, Protection | Planned | #12 | Manage protected caches without exposing terminal prompts in the main flow. |
| `mo uninstall` | Uninstall | In progress | #9 | App grid/list, app inspector, preview-first uninstall, Finder reveal, confirmation. |
| `mo uninstall --dry-run` | Uninstall preview | In progress | #9 | App-specific cleanup estimate and leftover folder count. Needs stable parsing or JSON. |
| `mo optimize` | Optimize | Planned | #10 | Maintenance tasks, cache/service refresh, diagnostics, whitelist visibility. |
| `mo optimize --dry-run` | Optimize preview | Planned | #10 | Required before enabling Optimize actions in the UI. |
| `mo optimize --whitelist` | Settings, Protection | Planned | #12 | User-managed protected optimization rules. |
| `mo analyze` / `mo analyse` | Analyze | Blocked by bundled Go binary work | #13 | Disk browser, large folders, large files, external volume selection. |
| `mo analyze --json` | Analyze data source | Blocked by bundled Go binary work | #13 | Prefer JSON for disk-map data instead of parsing TUI text. |
| `mo status` | Status, Overview | Blocked by bundled Go binary work | #13 | Live health dashboard, CPU, memory, disk, battery, network. |
| `mo status --json` | Status data source | Blocked by bundled Go binary work | #13 | Feed Overview health cards and live status panels. |
| `mo history` | History | Planned | #6 | Operation log browser with filters, failures, command source, reclaimed space. |
| `mo history --json` | History data source | Planned | #6 | Required for native table/list rendering. |
| `mo purge` | Storage, Projects | Planned | #11 | Project build artifacts, configured scan paths, language/tool categories. |
| `mo purge --dry-run` | Project purge preview | Planned | #11 | Required before showing project artifact cleanup actions. |
| `mo purge --paths` | Settings, Storage paths | Planned | #11 | Native path configuration for project scan directories. |
| `mo installer` | Storage, Installers | Planned | #11 | DMG, PKG, ZIP and installer-file discovery across common locations. |
| `mo installer --dry-run` | Installer preview | Planned | #11 | Required before installer cleanup action is visible. |
| `mo touchid` | Settings, Permissions | Planned | #14 | Optional sudo convenience setup, never required for basic app launch. |
| `mo touchid enable --dry-run` | Permissions preview | Planned | #14 | Show exact auth setup changes before applying. |
| `mo completion` | Settings, Advanced | Planned | #14 | Shell completion setup is useful for CLI users, not a primary cleanup card. |
| `mo completion --dry-run` | Completion preview | Planned | #14 | Keep as an advanced setup flow. |
| `mo update` | Settings, Updates | Planned | #14 | Direct download update flow or release-channel check. |
| `mo update --force` | Settings, Advanced updates | Planned | #14 | Advanced repair/reinstall action with confirmation. |
| `mo update --nightly` | Settings, Advanced updates | Planned | #14 | Hidden behind explicit prerelease/nightly setting. |
| `mo remove` | Settings, Advanced | Planned | #14 | App/runtime removal flow, not a homepage action. |
| `mo remove --dry-run` | Remove preview | Planned | #14 | Required before enabling removal. |
| `mo --version` | Diagnostics | Implemented | #7 | Show bundled runtime version and health. |
| `mo --help` | Diagnostics, Help | Planned | #7 | Use for capability checks, not for main UI rendering. |

## Main Screen Checklist

The Overview should summarize what the terminal makes possible without becoming a grid of fake buttons:

- Free space now: from clean, purge, installer, and uninstall previews.
- Installed apps with removable leftovers: from uninstall inventory and per-app preview.
- Large disk usage hotspots: from analyze JSON once bundled.
- System health: from status JSON once bundled.
- Maintenance suggestions: from optimize dry-run.
- Recent cleanup and total freed space: from history and local UI stats.

Each checklist item should have one of these states:

- Ready: opens a real module with preview support.
- Scanning: active command with cancellation.
- Needs permission: opens the permission guide once, then retries only on user action.
- Planned: hidden from primary actions until the command bridge exists.

## Module Build Order

1. Finish Clean and Uninstall because they already have visible UI and real command bridges.
2. Build Optimize with dry-run preview and whitelist visibility.
3. Build Storage as two real flows: Installer cleanup and Project artifact purge.
4. Bundle Analyze and Status Go binaries, then drive Overview health and disk maps from JSON.
5. Build History from `mo history --json` and operation logs.
6. Add Settings advanced flows for Touch ID, Completion, Update, and Remove.

## JSON And Bridge Gaps

- Uninstall preview should expose app size, leftover bytes, leftover path count, protected/skipped paths, and warnings as structured data.
- Optimize should expose tasks, risk level, dry-run changes, whitelist matches, and permission requirements.
- Purge should expose scan roots, artifact groups, bytes, item counts, language/tool category, and skipped paths.
- Installer should expose file path, kind, source, size, age, and whether it is safe to remove.
- History should expose operation id, command, dry-run flag, status, bytes, item count, timestamp, and log path.
- Analyze and Status should be bundled as app Resources and callable through the same cancellation-aware runner.
