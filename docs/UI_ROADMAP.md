# Libella Roadmap

Libella is a native macOS AppKit application for Mole. It should feel fast, polished, and fully native while keeping the CLI's safety model intact. The product goal is to compete with CleanMyMac on presentation and workflow quality without becoming more aggressive or less transparent about cleanup.

## Product Principles

- Native first: use AppKit controls, window behavior, menus, sheets, sidebars, toolbars, keyboard navigation, accessibility, and system appearance support.
- Safety first: every destructive UI flow must preview work before cleanup, require explicit confirmation, and route deletion through Mole's existing safe helpers.
- Fast by default: scanning, sizing, cleanup, and status refresh work must never block the main thread.
- Transparent cleanup: show what will be removed, why it is selected, what is skipped, and what requires manual review.
- Trust over theatrics: visual polish should clarify state and reduce anxiety, not pressure users into deleting more.
- CLI parity: the UI should expose Mole's core commands without duplicating destructive logic in AppKit code.

## Project Management

- Use GitHub Issues as the source of truth for Libella work items, bugs, design tasks, and release blockers.
- Use GitHub Milestones to group issues by roadmap phase, MVP scope, beta scope, and public release scope.
- Use GitHub Releases for shipped Libella builds, release notes, downloadable assets, and user-facing changelogs.
- Keep issue titles concrete and action-oriented. Each issue should describe the user impact, safety implications, and verification needed.
- Link pull requests to their tracking issues and release milestone before merge.
- Release notes should separate native UI changes from CLI changes when both ship in the same release.
- Use `docs/CLI_UI_PARITY.md` to decide which Mole terminal commands are ready to appear as real native UI actions.

## Architecture Direction

- App target: native macOS app built with AppKit.
- Distribution: Libella bundles the Mole CLI runtime inside the app, including `mo`, `mole`, `bin/`, `lib/`, and runtime support directories, so users do not need to install the CLI separately.
- App Store: Libella is not targeting Mac App Store distribution. Do not enable App Sandbox for the main cleanup app, because cleanup, uninstall, diagnostics, and filesystem review need access outside a sandbox.
- Core execution: call the bundled Mole command surfaces through a small, typed bridge layer that supports dry runs, JSON output, cancellation, progress, and structured errors.
- Safety boundary: the UI must not implement its own deletion engine. It must invoke the same core paths used by `mo clean`, `mo uninstall`, `mo analyze`, `mo optimize`, `mo purge`, and `mo installer`.
- Data contracts: prefer stable JSON output from CLI commands for UI integration. Add CLI JSON fields when needed instead of parsing terminal text.
- Concurrency: use background operation queues or Swift concurrency wrappers with main-thread UI updates only.
- Logging: surface operation history from Mole logs and keep existing operation logging behavior intact.
- Testability: keep scan parsing, command adapters, state reducers, and view models testable without launching the full app.

## Phase 0: Product Definition

- Define the first target macOS version and supported CPU architectures.
- Bundle the Mole CLI in the app and allow an alternate binary path only for development or advanced diagnostics.
- Define app identity, icon direction, bundle ID, signing, notarization, and update channel.
- Map each current command to a UI module: Clean, Uninstall, Analyze, Optimize, Status, Purge, Installer, History, Settings.
- Define the minimum JSON contracts needed for the first UI release.
- Write threat and safety notes for UI-triggered destructive actions.

Exit criteria:

- UI scope is documented.
- CLI integration strategy is chosen.
- Initial module list and JSON contract gaps are known.

## Phase 1: Native App Foundation

- Create the AppKit app target and project structure.
- Build a native main window with sidebar navigation and toolbar actions.
- Add appearance support for light mode, dark mode, vibrancy where appropriate, and high contrast accessibility.
- Add a command runner abstraction with dry-run support, cancellation, timeout handling, and structured stderr/stdout capture.
- Add app-wide state for active scans, pending cleanup jobs, errors, and operation history refresh.
- Add basic preferences for Mole binary path, dry-run defaults, and log visibility.
- Add a diagnostics screen that reports CLI availability, version, permissions, and common setup problems.

Exit criteria:

- The app launches quickly and feels native.
- Sidebar navigation works.
- The app can discover or run Mole safely in dry-run mode.
- Long-running commands are cancellable.

## Phase 2: Cleanup MVP

- Implement the Clean dashboard using dry-run data first.
- Show cleanup categories, estimated reclaimable space, skipped paths, protected paths, and warning states.
- Add category drill-down with file groups and reasons.
- Require explicit confirmation before cleanup.
- Run actual cleanup only through Mole core helpers.
- Show progress, completion summary, freed space, skipped items, and log link.
- Add error recovery for permission failures, missing binary, cancelled jobs, and partial cleanup.

Exit criteria:

- A user can preview and run `mo clean` safely from the app.
- No destructive action can run without preview and confirmation.
- Cleanup result is reflected in operation history.

## Phase 3: Core Feature Parity

- Uninstall: app inventory, protected app warnings, related file preview, confirmation, cleanup results.
- Analyze: disk usage browser, large file review, safe Trash routing, external volume selection.
- Optimize: task list, whitelist visibility, dry-run preview, confirmation for higher-risk tasks.
- Purge: project scan paths, artifact categories, dry-run preview, cleanup results.
- Installer: installer discovery, filters, preview, and cleanup.
- Status: live CPU, memory, disk, battery, network, and health indicators where available.
- History: operation log browser with filters, command source, timestamp, reclaimed space, and failure detail.

Exit criteria:

- The UI covers the primary Mole command surface.
- Each destructive module has preview, confirmation, progress, result, and history behavior.
- Protected paths and app protection are visible in the UI when they affect results.

## Phase 4: Polish And Performance

- Tune launch time, navigation latency, scan progress responsiveness, and memory use.
- Add native empty states, loading states, error sheets, confirmation sheets, and detail inspectors.
- Add keyboard shortcuts and menu commands for scan, cancel, refresh, preferences, help, and history.
- Add VoiceOver labels, focus order, reduced motion behavior, and Dynamic Type where practical for macOS.
- Add smooth but restrained animations for progress, list updates, and state transitions.
- Add icons and visual hierarchy for categories without relying on loud colors or pressure tactics.
- Add persistent window layout and user preferences.

Exit criteria:

- The app feels responsive during large scans.
- Common workflows require minimal clicks.
- Accessibility and keyboard usage are credible.
- Visual QA passes on light mode, dark mode, compact windows, and large displays.

## Phase 5: Trust, Distribution, And Beta

- Add code signing and notarization.
- Add crash reporting strategy if desired, with clear privacy defaults.
- Add in-app update strategy or release channel integration.
- Add first-run onboarding focused on safety, permissions, and what Mole will never delete automatically.
- Add beta feedback flow and diagnostic export that redacts sensitive paths where appropriate.
- Create a manual QA checklist for destructive flows, permission prompts, cancellation, and recovery.
- Run closed beta against real-world Macs with different macOS versions and disk states.

Exit criteria:

- Signed app can be installed and launched without Gatekeeper friction.
- Beta users can report issues with useful diagnostics.
- Safety-critical flows pass manual QA.

## Phase 6: Public Release

- Finalize landing page and docs for the native app.
- Publish release notes that clearly distinguish CLI and UI changes.
- Add screenshots and short workflow demos.
- Confirm Homebrew, direct download, and update story.
- Monitor beta feedback, crashes, and cleanup logs for release blockers.
- Freeze risky cleanup changes before launch unless they fix a safety issue.

Exit criteria:

- Public build is signed, notarized, documented, and recoverable.
- Support path is clear.
- Release notes match shipped behavior.

## Initial UI Modules

- Overview: disk pressure, reclaimable space, recent cleanup, health summary, quick actions.
- Clean: system caches, user caches, browser caches, logs, developer caches, app leftovers.
- Uninstall: installed apps, protected apps, leftover review, app metadata.
- Analyze: disk browser, largest folders, large files, old downloads, external volumes.
- Optimize: maintenance tasks, whitelist, service refresh, diagnostics.
- Purge: project artifacts, configured scan paths, language and build tool categories.
- Installer: disk images, packages, archives, downloaded installers.
- Status: live system dashboard and menu bar summary.
- History: operation logs, dry-run records, cleanup summaries, failures.
- Settings: Mole binary, update channel, dry-run preference, logs, privacy, advanced options.

## Engineering Backlog

- Add or stabilize JSON output for every command used by the UI.
- Add progress output where commands currently only print final summaries.
- Add cancellation behavior that leaves partial operations in a safe and logged state.
- Add integration tests for UI-facing JSON contracts.
- Add fixtures for representative dry-run outputs.
- Add a CLI capability endpoint such as `mo --json capabilities`.
- Add a machine-readable list of protected paths and app protection decisions.
- Add operation IDs so UI jobs can correlate command runs with log entries.
- Add structured error codes for permissions, protected paths, missing tools, cancellation, and partial success.

## Safety Checklist For Every UI Flow

- Starts in dry-run or preview mode.
- Shows exact categories and enough detail to understand risk.
- Shows skipped and protected items.
- Requires explicit confirmation before destructive work.
- Uses Mole core helpers for deletion.
- Supports cancellation when the underlying command can cancel safely.
- Writes operation logs.
- Handles permission failures without retry loops or hidden escalation.
- Avoids prompting for sudo during automated verification.
- Has tests for protected paths and app protection behavior when applicable.

## Suggested First Milestone

GitHub milestone: [Libella v0.1 MVP](https://github.com/misaellandero/MoleUI/milestone/1)

Build the smallest credible AppKit app:

1. Native sidebar window with Overview, Clean, History, and Settings.
2. Mole binary discovery and version display.
3. `mo clean --dry-run --json` integration or the closest available JSON contract.
4. Category summary list with reclaimable space and skipped/protected counts.
5. Confirmation sheet that runs cleanup through the CLI bridge.
6. Progress, cancellation, result summary, and operation history refresh.

This milestone proves the product shape, the safety boundary, and the CLI-to-AppKit integration before expanding into uninstall, analyze, optimize, purge, and status.

Tracking issues:

- [#1 Define Libella v0.1 product scope and safety boundaries](https://github.com/misaellandero/MoleUI/issues/1)
- [#2 Build native AppKit app shell with sidebar navigation](https://github.com/misaellandero/MoleUI/issues/2)
- [#3 Implement safe Mole CLI bridge for AppKit](https://github.com/misaellandero/MoleUI/issues/3)
- [#4 Add JSON contract for Clean preview data](https://github.com/misaellandero/MoleUI/issues/4)
- [#5 Build Clean MVP preview, confirmation, progress, and result flow](https://github.com/misaellandero/MoleUI/issues/5)
- [#6 Build History screen from Mole operation logs](https://github.com/misaellandero/MoleUI/issues/6)
- [#7 Build Settings and Diagnostics for Mole binary and safety defaults](https://github.com/misaellandero/MoleUI/issues/7)
- [#8 Prepare v0.1 packaging, signing, and release checklist](https://github.com/misaellandero/MoleUI/issues/8)
