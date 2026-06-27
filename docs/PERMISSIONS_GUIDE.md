# Libella Permissions Guide

Libella needs broad file visibility to preview cleanup and uninstall leftovers without prompting repeatedly. Grant permissions before the first full scan.

Libella should not start protected scans automatically. The app only scans protected app data after the user starts a scan, preview, or app load action. If Full Disk Access is not granted, macOS may show "Libella would like to access data from other apps" every time protected locations are touched.

## Required

### Full Disk Access

1. Open System Settings.
2. Go to Privacy & Security.
3. Open Full Disk Access.
4. Add Libella.
5. Quit and reopen Libella.

This lets the app inspect user Library caches, app support folders, logs, containers, downloads, and leftovers without repeated macOS prompts.

## Recommended

### Files And Folders

If macOS asks for access to Desktop, Documents, Downloads, removable volumes, or network volumes, allow it. These prompts can appear when scanning installers, old downloads, project artifacts, or external drives.

### Removable Volumes

Allow removable volume access if the app will scan external drives or clean mounted-volume metadata.

### Accessibility

Not required for normal cleanup. Only enable this if a future feature explicitly needs UI automation.

## Optional

### Touch ID For Sudo

Some maintenance tasks may need administrator privileges. Libella should avoid hidden sudo prompts in automatic flows, but users can configure Touch ID for terminal sudo separately:

```bash
mo touchid enable --dry-run
mo touchid enable
```

Use the dry-run first to preview the sudo configuration change.

## Safety Notes

- Cleanup and uninstall actions should start with a preview.
- Destructive actions should require explicit confirmation.
- The app should not ask for permissions inside a loop.
- If a scan returns incomplete results, verify Full Disk Access first.
- If permissions were changed while the app was open, quit and reopen the app.
