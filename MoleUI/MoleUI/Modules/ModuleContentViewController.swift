//
//  ModuleContentViewController.swift
//  Libella
//

import Cocoa
import QuartzCore
import SwiftUI

final class ModuleContentViewController: NSViewController {

    // MARK: — ViewModels

    let overviewVM: OverviewViewModel
    let cleanVM: CleanViewModel
    let uninstallVM: UninstallViewModel
    let diagnosticsVM: DiagnosticsViewModel

    private func activeViewModel(for module: AppModule) -> any ModuleViewModel {
        switch module {
        case .overview:    return overviewVM
        case .clean:       return cleanVM
        case .uninstall:   return uninstallVM
        case .diagnostics: return diagnosticsVM
        default:           return diagnosticsVM
        }
    }

    // Render-generation token used by reloadAppCatalog to skip stale batches.
    private var appCatalogRenderGeneration = 0
    private var lastRenderedCatalogGeneration = -1

    var module: AppModule = .overview {
        didSet {
            activeViewModel(for: oldValue).cancel()
            if module == .overview { overviewVM.deactivate() }
            activeViewModel(for: module).activate()
            render()
            startAutomaticPreviewIfNeeded()
        }
    }

    // MARK: — UI Controls

    private let titleField = NSTextField(labelWithString: "")
    private let subtitleField = NSTextField(wrappingLabelWithString: "")
    private let primaryActionButton = NSButton(title: "", target: nil, action: nil)
    private let secondaryActionButton = NSButton(title: "", target: nil, action: nil)
    private let actionStack = NSStackView()
    private let activityField = NSTextField(labelWithString: "")
    private let commandProgressContainer = NSView()
    private let commandProgressIndicator = NSProgressIndicator()
    private let commandProgressLineField = NSTextField(labelWithString: "")
    private let commandProgressSpaceField = NSTextField(labelWithString: "")
    private let selectionLabel = NSTextField(labelWithString: "App")
    private let appSelector = NSPopUpButton()
    private let selectionCountField = NSTextField(labelWithString: "")
    private let selectionContainer = NSStackView()
    private let showCLIOutputButton = NSButton(checkboxWithTitle: "Show CLI output", target: nil, action: nil)
    private let operationEffectContainer = NSView()
    private var operationEffectView: NSHostingView<OperationEffectView>?
    private let appCatalogControls = NSStackView()
    private let appSearchField = NSSearchField()
    private let appSortPopup = NSPopUpButton()
    private let appInspectorView = AppInspectorView()
    private let appCatalogScrollView = NSScrollView()
    private let appCatalogStack = NSStackView()
    private let previewTextView = NSTextView()
    private let previewScrollView = NSScrollView()
    private let statusContainer = NSStackView()
    private let detailContainer = NSStackView()
    private let ambientBackgroundContainer = NSView()
    private var ambientBackgroundView: NSHostingView<GlobalAmbientBackgroundView>?
    private let ambientCLIContainer = NSView()
    private var ambientCLIHostingView: NSHostingView<AmbientCLIView>?
    private let contentScrollView = NSScrollView()
    private let contentDocumentView = NSView()

    // MARK: — Init

    init(commandRunner: MoleCommandRunning = MoleCommandRunner()) {
        let overview = OverviewViewModel(commandRunner: commandRunner)
        let clean = CleanViewModel(commandRunner: commandRunner)
        let uninstall = UninstallViewModel(commandRunner: commandRunner)
        let diagnostics = DiagnosticsViewModel(commandRunner: commandRunner)

        self.overviewVM = overview
        self.cleanVM = clean
        self.uninstallVM = uninstall
        self.diagnosticsVM = diagnostics

        super.init(nibName: nil, bundle: nil)

        clean.onCleanCompleted = { [weak overview, weak uninstall] summary, freedBytes in
            overview?.acceptCleanResult(summary: summary, freedBytes: freedBytes)
            if let count = uninstall?.apps.count { overview?.acceptUninstallCount(count) }
        }
        uninstall.onUninstallCompleted = { [weak self] app, summary in
            self?.cleanupStats.recordUninstall(appName: app.name, freedBytes: summary?.estimatedBytes)
            self?.overviewVM.refreshDiskSpace()
        }
    }

    required init?(coder: NSCoder) {
        let runner = MoleCommandRunner()
        self.overviewVM = OverviewViewModel(commandRunner: runner)
        self.cleanVM = CleanViewModel(commandRunner: runner)
        self.uninstallVM = UninstallViewModel(commandRunner: runner)
        self.diagnosticsVM = DiagnosticsViewModel(commandRunner: runner)
        super.init(coder: coder)
    }

    // MARK: — Lifecycle

    private var cleanupStats = CleanupStatsStore.load()

    override func loadView() {
        view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        configureView()

        let notify = { [weak self] in
            DispatchQueue.main.async { self?.render() }
        }
        overviewVM.onChange = notify
        cleanVM.onChange = notify
        uninstallVM.onChange = notify
        diagnosticsVM.onChange = notify

        render()
        startAutomaticPreviewIfNeeded()
        NotificationCenter.default.addObserver(self, selector: #selector(visualSettingsChanged), name: .visualSettingsChanged, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: — Public coordinator interface

    func performPrimaryAction() {
        switch module {
        case .overview:
            guard confirmPrivacySensitiveScanIfNeeded() else { return }
            overviewVM.runScan(status: "Scanning cleanup opportunities...")
        case .clean:
            guard confirmPrivacySensitiveScanIfNeeded() else { return }
            cleanVM.runPreview(status: "Running safe clean dry-run...")
        case .uninstall:
            guard confirmPrivacySensitiveScanIfNeeded() else { return }
            uninstallVM.loadApps(status: uninstallVM.apps.isEmpty ? "Loading installed apps..." : "Refreshing installed apps...")
        case .diagnostics:
            diagnosticsVM.runChecks()
        default:
            activityField.stringValue = module.placeholderMessage
        }
    }

    func performSecondaryAction() {
        switch module {
        case .clean:
            runAutomaticClean()
        case .uninstall:
            guard let app = uninstallVM.pendingUninstallApp else { return }
            runConfirmedUninstall(app)
        default:
            performRefresh()
        }
    }

    func performRefresh() {
        switch module {
        case .clean:
            cleanVM.previewSummary = nil
            guard confirmPrivacySensitiveScanIfNeeded() else { return }
            cleanVM.runPreview(status: "Refreshing cleanup preview...")
        case .uninstall:
            guard confirmPrivacySensitiveScanIfNeeded() else { return }
            uninstallVM.loadApps(status: "Refreshing installed apps...")
        case .diagnostics:
            diagnosticsVM.runChecks()
        default:
            activityField.stringValue = "\(module.title) refreshed."
        }
    }

    func performCancel() {
        let vm = activeViewModel(for: module)
        guard vm.isRunning else {
            activityField.stringValue = "No command is running."
            return
        }
        vm.cancel()
        setBusy(false)
    }

    func confirmNavigationAwayIfNeeded(to targetModule: AppModule) -> Bool {
        let vm = activeViewModel(for: module)
        guard vm.isRunning, targetModule != module else { return true }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Scan in Progress"
        alert.informativeText = "The current scan is still working. Leaving this section will cancel it, so the latest results may not be available."
        alert.addButton(withTitle: "Stay Here")
        alert.addButton(withTitle: "Cancel Scan and Leave")
        guard alert.runModal() == .alertSecondButtonReturn else { return false }

        performCancel()
        return true
    }

    // MARK: — Automatic preview

    private func startAutomaticPreviewIfNeeded() {
        let vm = activeViewModel(for: module)
        guard isViewLoaded, !vm.isRunning else { return }

        switch module {
        case .overview:
            overviewVM.diskSpaceSummary = DiskSpaceSummary.load()
        default:
            break
        }
    }

    // MARK: — Privacy gate (AppKit dialog, stays in VC)

    private func confirmPrivacySensitiveScanIfNeeded() -> Bool {
        guard !PrivacyPromptPolicy.didShowAccessGuide else { return true }
        PrivacyPromptPolicy.didShowAccessGuide = true

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Allow Disk Access Once"
        alert.informativeText = "macOS may ask for access to data from other apps during scans. Grant Full Disk Access in System Settings so previews do not trigger repeated prompts."
        alert.addButton(withTitle: "Open Full Disk Access")
        alert.addButton(withTitle: "Continue Scan")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            PrivacyPromptPolicy.openFullDiskAccessSettings()
            activityField.stringValue = "Grant Full Disk Access, then run the scan again."
            return false
        }
        if response == .alertSecondButtonReturn { return true }

        activityField.stringValue = "Scan cancelled before requesting protected app data."
        return false
    }

    // MARK: — Clean confirmation dialog (AppKit dialog, stays in VC)

    private func runAutomaticClean() {
        guard cleanVM.previewOutput != nil else {
            activityField.stringValue = "Run a clean preview before freeing space."
            return
        }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Free Space Now?"
        alert.informativeText = "The app will run `mo clean` using the bundled runtime. Sudo-only system caches stay skipped so the app does not block on authorization."
        alert.addButton(withTitle: "Free Space")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else {
            activityField.stringValue = "Clean cancelled before execution."
            return
        }
        let expectedSummary = cleanVM.previewSummary
        cleanVM.executeClean(expectedSummary: expectedSummary)
        cleanupStats.recordClean(freedBytes: expectedSummary?.potentialSpaceBytes)
    }

    private func runConfirmedUninstall(_ app: InstalledApp) {
        guard uninstallVM.previewedAppName == app.uninstallName else {
            uninstallVM.selectApp(app, showConfirmation: true)
            return
        }
        let summary = uninstallVM.pendingUninstallSummary
        uninstallVM.executeUninstall(app: app, expectedSummary: summary)
    }

    // MARK: — @objc targets

    @objc private func primaryActionClicked()   { performPrimaryAction() }
    @objc private func secondaryActionClicked() { performSecondaryAction() }

    @objc private func toggleCLIOutput() {
        uninstallVM.showCLIOutput = showCLIOutputButton.state == .on
        cleanVM.showCLIOutput = showCLIOutputButton.state == .on
        renderSupplementalContent()
    }

    @objc private func appCardSelected(_ sender: InstalledAppCardView) {
        guard let app = uninstallVM.app(for: sender.uninstallName) else { return }
        uninstallVM.selectApp(app, showConfirmation: true)
        appInspectorView.configureLoading(app: app)
        renderSupplementalContent()
    }

    @objc private func confirmPendingUninstall() {
        guard let app = uninstallVM.pendingUninstallApp else { return }
        runConfirmedUninstall(app)
    }

    @objc private func cancelPendingUninstall() {
        uninstallVM.pendingUninstallApp = nil
        uninstallVM.pendingUninstallSummary = nil
        updateAppInspector()
        activityField.stringValue = "Uninstall cancelled before confirmation."
    }

    @objc private func revealInspectedAppInFinder() {
        guard let app = uninstallVM.inspectedApp else {
            activityField.stringValue = "Select an app to reveal it in Finder."
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: app.path)])
        activityField.stringValue = "Revealed \(app.name) in Finder."
    }

    @objc private func appSearchChanged() {
        uninstallVM.searchQuery = appSearchField.stringValue
        reloadAppCatalog()
    }

    @objc private func appSortChanged() {
        uninstallVM.sortMode = AppSortMode(rawValue: appSortPopup.indexOfSelectedItem) ?? .nameAscending
        reloadAppCatalog()
    }

    @objc private func visualSettingsChanged() {
        ambientBackgroundView?.rootView = GlobalAmbientBackgroundView(isEnabled: VisualSettings.particlesEnabled)
        render()
    }

    // MARK: — Render

    func render() {
        guard isViewLoaded else { return }

        let vm = activeViewModel(for: module)

        titleField.stringValue = module.title
        subtitleField.stringValue = module.subtitle
        activityField.stringValue = vm.statusMessage

        updateActionButtons()
        updateCommandProgress()
        renderSupplementalContent()
        configureStatusLayout(for: module)
        statusContainer.setArrangedSubviews(statusCards(for: module))
        detailContainer.setArrangedSubviews(detailRows(for: module))

        setBusy(vm.isRunning)
    }

    private func updateCommandProgress() {
        switch module {
        case .clean:
            commandProgressLineField.stringValue = cleanVM.lastProgressLine
            commandProgressLineField.textColor = cleanVM.progressLineIsError ? .systemOrange : .secondaryLabelColor
            commandProgressSpaceField.stringValue = ByteCountFormatter.storageString(from: cleanVM.progressDisplayedBytes)
            commandProgressSpaceField.alphaValue = cleanVM.progressDisplayedBytes > 0 ? 1 : 0.62
        default:
            break
        }
    }

    private func configureStatusLayout(for module: AppModule) {
        if module == .overview {
            statusContainer.orientation = .vertical
            statusContainer.alignment = .leading
            statusContainer.distribution = .fill
            statusContainer.spacing = 14
        } else {
            statusContainer.orientation = .horizontal
            statusContainer.alignment = .top
            statusContainer.distribution = .fillEqually
            statusContainer.spacing = 14
        }
    }

    private func renderSupplementalContent() {
        let showCLIOutput = module == .clean ? cleanVM.showCLIOutput : uninstallVM.showCLIOutput
        selectionContainer.isHidden = true
        appCatalogControls.isHidden = module != .uninstall
        appCatalogStack.isHidden = module != .uninstall
        showCLIOutputButton.isHidden = module == .overview || module == .history || module == .clean
        showCLIOutputButton.state = showCLIOutput ? .on : .off
        previewScrollView.isHidden = !showCLIOutput || module == .overview || module == .history || module == .clean
        ambientCLIContainer.isHidden = module != .clean

        switch module {
        case .uninstall:
            let visibleCount = uninstallVM.visibleApps.count
            selectionCountField.stringValue = uninstallVM.apps.isEmpty
                ? "No apps loaded"
                : "\(visibleCount) of \(uninstallVM.apps.count) apps"
            if lastRenderedCatalogGeneration != uninstallVM.renderGeneration {
                lastRenderedCatalogGeneration = uninstallVM.renderGeneration
                reloadAppCatalog()
            }
            updateAppInspector()
        default:
            selectionCountField.stringValue = ""
            appInspectorView.isHidden = true
        }

        updatePreviewText()
    }

    private func updateActionButtons() {
        let vm = activeViewModel(for: module)
        let busy = vm.isRunning
        let primaryTitle: String
        let secondaryTitle: String
        let primaryEnabled: Bool
        let secondaryEnabled: Bool

        switch module {
        case .overview:
            primaryTitle = "Scan"
            secondaryTitle = "Refresh"
            primaryEnabled = !busy
            secondaryEnabled = false
        case .clean:
            primaryTitle = "Preview Clean"
            secondaryTitle = "Free Space"
            primaryEnabled = !busy
            secondaryEnabled = !busy && cleanVM.previewOutput != nil
        case .uninstall:
            primaryTitle = uninstallVM.apps.isEmpty ? "Load Apps" : "Refresh Apps"
            secondaryTitle = ""
            primaryEnabled = !busy
            secondaryEnabled = false
        case .history:
            primaryTitle = "Load History"
            secondaryTitle = "Refresh"
            primaryEnabled = false
            secondaryEnabled = false
        case .diagnostics:
            primaryTitle = "Run Checks"
            secondaryTitle = ""
            primaryEnabled = !busy
            secondaryEnabled = false
        }

        primaryActionButton.title = primaryTitle
        secondaryActionButton.title = secondaryTitle
        primaryActionButton.isEnabled = primaryEnabled
        secondaryActionButton.isEnabled = secondaryEnabled
        primaryActionButton.isHidden = !primaryEnabled
        secondaryActionButton.isHidden = !secondaryEnabled
        actionStack.isHidden = primaryActionButton.isHidden && secondaryActionButton.isHidden
    }

    private func updatePreviewText() {
        switch module {
        case .clean:
            ambientCLIHostingView?.rootView = AmbientCLIView(
                lines: cleanVM.cliLines,
                isRunning: cleanVM.isRunning,
                placeholder: "Run a preview to inspect cleanup output before freeing space."
            )
        case .uninstall:
            if let preview = uninstallVM.previewOutput,
               uninstallVM.previewedAppName == uninstallVM.inspectedApp?.uninstallName {
                previewTextView.string = preview
            } else if let app = uninstallVM.inspectedApp {
                previewTextView.string = "Selected app: \(app.name)\nSize: \(app.size)\nPath: \(app.path)\n\nRun a preview before uninstalling."
            } else {
                previewTextView.string = "Select an app to inspect its preview output."
            }
        case .diagnostics:
            if !diagnosticsVM.outputText.isEmpty {
                previewTextView.string = diagnosticsVM.outputText
            } else if previewTextView.string.isEmpty {
                previewTextView.string = "Run diagnostics to verify the bundled runtime and environment."
            }
        default:
            previewTextView.string = ""
        }
    }

    private func setBusy(_ busy: Bool, showsOperationEffect: Bool = true) {
        primaryActionButton.isEnabled = !busy
        secondaryActionButton.isEnabled = !busy
        operationEffectContainer.isHidden = !busy || !showsOperationEffect
        commandProgressContainer.isHidden = !busy
        if busy, showsOperationEffect {
            operationEffectView?.rootView = OperationEffectView(title: module.busyTitle, subtitle: module.busySubtitle)
        }
        if busy {
            commandProgressIndicator.startAnimation(nil)
        } else {
            commandProgressIndicator.stopAnimation(nil)
        }
    }

    // MARK: — App catalog (NSView lifecycle, stays in VC)

    private func reloadAppCatalog() {
        appCatalogRenderGeneration += 1
        let gen = appCatalogRenderGeneration
        appCatalogStack.setArrangedSubviews([])

        let apps = uninstallVM.visibleApps
        if uninstallVM.apps.isEmpty {
            appCatalogStack.addArrangedSubview(AppCatalogEmptyView())
            return
        }
        if apps.isEmpty {
            appCatalogStack.addArrangedSubview(AppCatalogEmptyView(
                title: "No matching apps",
                detail: "Adjust the search text or sorting option to find another app."
            ))
            return
        }
        appendAppCatalogBatch(apps, startingAt: 0, renderGeneration: gen)
    }

    private func appendAppCatalogBatch(_ apps: [InstalledApp], startingAt startIndex: Int, renderGeneration: Int) {
        guard appCatalogRenderGeneration == renderGeneration else { return }
        let batchSize = 24
        let endIndex = min(startIndex + batchSize, apps.count)
        for app in apps[startIndex..<endIndex] {
            addAppCatalogCard(app)
        }
        guard endIndex < apps.count else { return }
        DispatchQueue.main.async { [weak self] in
            self?.appendAppCatalogBatch(apps, startingAt: endIndex, renderGeneration: renderGeneration)
        }
    }

    private func addAppCatalogCard(_ app: InstalledApp) {
        let card = InstalledAppCardView(
            app: app,
            isSelected: uninstallVM.inspectedApp?.uninstallName == app.uninstallName,
            onSelect: { [weak self] selectedCard in
                guard let self, let selectedApp = self.uninstallVM.app(for: selectedCard.uninstallName) else { return }
                self.uninstallVM.selectApp(selectedApp, showConfirmation: true)
                self.appInspectorView.configureLoading(app: selectedApp)
                self.renderSupplementalContent()
            }
        )
        appCatalogStack.addArrangedSubview(card)
        card.widthAnchor.constraint(equalTo: appCatalogStack.widthAnchor, constant: -8).isActive = true
    }

    private func updateAppInspector() {
        guard let app = uninstallVM.inspectedApp else {
            appInspectorView.configureEmpty()
            appInspectorView.isHidden = uninstallVM.apps.isEmpty
            return
        }
        let preview = uninstallVM.previewedAppName == app.uninstallName ? uninstallVM.pendingUninstallSummary : nil
        appInspectorView.configure(app: app, preview: preview)
        appInspectorView.isHidden = false
    }

    // MARK: — Status cards & detail rows

    private func statusCards(for module: AppModule) -> [NSView] {
        switch module {
        case .overview:
            return [
                DiskSpaceSummaryHostView(
                    summary: overviewVM.diskSpaceSummary,
                    cleanupStats: cleanupStats,
                    reclaimableSpace: overviewVM.cleanPreviewSummary?.potentialSpace,
                    reclaimableKB: overviewVM.cleanPreviewSummary?.potentialSpaceKB,
                    isScanning: overviewVM.isRunning,
                    canFreeSpace: overviewVM.cleanPreviewOutput != nil && !overviewVM.isRunning,
                    celebrationID: overviewVM.spaceCelebrationID,
                    onFreeSpace: { [weak self] in self?.runAutomaticClean() }
                ),
                OptimizationPlanHostView(
                    items: optimizationPlanItems(),
                    isRefreshing: overviewVM.isRunning
                ) { [weak self] targetModule in
                    guard let self, self.confirmNavigationAwayIfNeeded(to: targetModule) else { return }
                    self.module = targetModule
                }
            ]
        case .clean:
            return [
                MetricCardView(title: "Potential Space", value: cleanVM.previewSummary?.potentialSpace ?? "Not scanned", detail: "Derived from `mo clean --dry-run`."),
                MetricCardView(title: "Items", value: cleanVM.previewSummary?.itemCount ?? "-", detail: "Files or groups identified by the preview."),
                MetricCardView(title: "Categories", value: cleanVM.previewSummary?.categoryCount ?? "-", detail: "Cleanup sections reported by the runtime.")
            ]
        case .uninstall:
            return []
        case .history:
            return [
                MetricCardView(title: "Operations", value: "Not loaded", detail: "Reads operation logs."),
                MetricCardView(title: "Failures", value: "Pending", detail: "Structured errors will appear here."),
                MetricCardView(title: "Dry Runs", value: "Pending", detail: "Preview records stay reviewable.")
            ]
        case .diagnostics:
            return [
                MetricCardView(title: "Runtime", value: "Bundled", detail: "Diagnostics call the command runtime shipped inside the app."),
                MetricCardView(title: "Permissions", value: "Passive", detail: "No hidden sudo checks."),
                MetricCardView(title: "Environment", value: "Inspectable", detail: "Command output appears in the preview pane.")
            ]
        }
    }

    private func optimizationPlanItems() -> [OptimizationPlanItem] {
        [
            OptimizationPlanItem(
                title: "Deep cleanup",
                value: overviewVM.cleanPreviewSummary?.potentialSpace ?? "Scanning",
                detail: overviewVM.cleanPreviewSummary == nil
                    ? "Previewing system junk, app caches, logs, downloads, and safe leftovers without deleting anything."
                    : "\(overviewVM.cleanPreviewSummary?.itemCount ?? "-") candidates across \(overviewVM.cleanPreviewSummary?.categoryCount ?? "-") cleanup groups.",
                action: "Start with Clean",
                symbolName: "sparkles",
                color: .systemTeal,
                targetModule: .clean
            ),
            OptimizationPlanItem(
                title: "Applications",
                value: overviewVM.uninstallAppCount == 0 ? "Loading" : "\(overviewVM.uninstallAppCount)",
                detail: "Sort installed apps by size, search quickly, inspect leftovers, then confirm only the apps you choose.",
                action: "Review apps",
                symbolName: "rectangle.stack.badge.minus",
                color: .systemIndigo,
                targetModule: .uninstall
            )
        ]
    }

    private func detailRows(for module: AppModule) -> [NSView] {
        switch module {
        case .overview:
            return [
                DetailRowView(symbolName: "checkmark.shield", title: "Preview-first cleanup", detail: "Every cleanup starts as a summary before anything is removed."),
                DetailRowView(symbolName: "clock", title: "Background CLI work", detail: "Long-running scans and cleanups stay off the main thread."),
                DetailRowView(symbolName: "shippingbox", title: "Bundled runtime", detail: "The app ships with its cleanup runtime instead of requiring a separate install.")
            ]
        case .clean:
            return [
                DetailRowView(symbolName: "waveform", title: "Live output", detail: "CLI lines flow in as they arrive and fade naturally after the run completes."),
                DetailRowView(symbolName: "exclamationmark.shield", title: "Authorization policy", detail: "The app keeps sudo-only cleanup out of the automatic flow so it never blocks on auth."),
                DetailRowView(symbolName: "trash", title: "Runtime path", detail: "Real cleanup still runs through the audited command path, not AppKit-only code.")
            ]
        case .uninstall:
            return [
                DetailRowView(symbolName: "1.circle", title: "Step 1: Choose an app", detail: "Select the app you no longer want. Nothing is removed when you click it."),
                DetailRowView(symbolName: "2.circle", title: "Step 2: See what will be removed", detail: "The app checks the app itself plus support files, caches, settings, and leftovers macOS can leave behind."),
                DetailRowView(symbolName: "3.circle", title: "Step 3: Confirm uninstall", detail: "Review the space you can free, then press Uninstall only when you are ready.")
            ]
        case .history:
            return [
                DetailRowView(symbolName: "calendar", title: "Timeline", detail: "Timestamped operations with result and command source."),
                DetailRowView(symbolName: "line.3.horizontal.decrease.circle", title: "Filters", detail: "Dry runs, real cleanups, errors, and module source."),
                DetailRowView(symbolName: "arrow.clockwise", title: "Refresh after cleanup", detail: "Completed cleanup will refresh history automatically.")
            ]
        case .diagnostics:
            return [
                DetailRowView(symbolName: "checkmark.circle", title: "Availability", detail: "Verify the bundled runtime version and command access."),
                DetailRowView(symbolName: "wrench.and.screwdriver", title: "Actionable errors", detail: "Failures are surfaced as structured launch, permission, timeout, or exit-code errors."),
                DetailRowView(symbolName: "eye", title: "Raw output", detail: "The preview pane exposes CLI output so the bridge stays transparent.")
            ]
        }
    }

    // MARK: — View setup (unchanged)

    private func configureView() {
        let rootStack = NSStackView()
        rootStack.orientation = .vertical
        rootStack.alignment = .leading
        rootStack.spacing = 20
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        rootStack.wantsLayer = true

        contentScrollView.translatesAutoresizingMaskIntoConstraints = false
        contentScrollView.drawsBackground = false
        contentScrollView.hasVerticalScroller = true
        contentScrollView.autohidesScrollers = true
        contentScrollView.borderType = .noBorder
        contentScrollView.documentView = contentDocumentView
        contentDocumentView.translatesAutoresizingMaskIntoConstraints = false

        ambientBackgroundContainer.translatesAutoresizingMaskIntoConstraints = false
        let ambientHost = NSHostingView(rootView: GlobalAmbientBackgroundView(isEnabled: VisualSettings.particlesEnabled))
        ambientHost.translatesAutoresizingMaskIntoConstraints = false
        ambientBackgroundContainer.addSubview(ambientHost)
        ambientBackgroundView = ambientHost

        titleField.font = .systemFont(ofSize: 34, weight: .semibold)
        titleField.lineBreakMode = .byTruncatingTail

        subtitleField.font = .systemFont(ofSize: 14)
        subtitleField.textColor = .secondaryLabelColor
        subtitleField.maximumNumberOfLines = 2

        let headerStack = NSStackView(views: [titleField, subtitleField])
        headerStack.orientation = .vertical
        headerStack.alignment = .leading
        headerStack.spacing = 6

        primaryActionButton.bezelStyle = .rounded
        primaryActionButton.controlSize = .large
        primaryActionButton.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Primary action")
        primaryActionButton.imagePosition = .imageLeading
        primaryActionButton.target = self
        primaryActionButton.action = #selector(primaryActionClicked)

        secondaryActionButton.bezelStyle = .rounded
        secondaryActionButton.controlSize = .large
        secondaryActionButton.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Secondary action")
        secondaryActionButton.imagePosition = .imageLeading
        secondaryActionButton.target = self
        secondaryActionButton.action = #selector(secondaryActionClicked)

        actionStack.orientation = .horizontal
        actionStack.spacing = 10
        actionStack.addArrangedSubview(primaryActionButton)
        actionStack.addArrangedSubview(secondaryActionButton)

        activityField.font = .systemFont(ofSize: 12)
        activityField.textColor = .secondaryLabelColor
        activityField.stringValue = "Ready."

        commandProgressContainer.translatesAutoresizingMaskIntoConstraints = false
        commandProgressContainer.wantsLayer = true
        commandProgressContainer.layer?.cornerRadius = 8
        commandProgressContainer.layer?.backgroundColor = NSColor(calibratedRed: 0.06, green: 0.10, blue: 0.26, alpha: 0.85).cgColor
        commandProgressContainer.isHidden = true

        commandProgressIndicator.style = .spinning
        commandProgressIndicator.controlSize = .small
        commandProgressIndicator.translatesAutoresizingMaskIntoConstraints = false

        commandProgressLineField.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        commandProgressLineField.textColor = .secondaryLabelColor
        commandProgressLineField.lineBreakMode = .byTruncatingHead
        commandProgressLineField.maximumNumberOfLines = 1
        commandProgressLineField.stringValue = "Waiting for command output..."
        commandProgressLineField.translatesAutoresizingMaskIntoConstraints = false

        commandProgressSpaceField.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        commandProgressSpaceField.textColor = .controlAccentColor
        commandProgressSpaceField.alignment = .right
        commandProgressSpaceField.stringValue = ByteCountFormatter.storageString(from: 0)
        commandProgressSpaceField.translatesAutoresizingMaskIntoConstraints = false

        commandProgressContainer.addSubview(commandProgressIndicator)
        commandProgressContainer.addSubview(commandProgressLineField)
        commandProgressContainer.addSubview(commandProgressSpaceField)

        NSLayoutConstraint.activate([
            commandProgressContainer.heightAnchor.constraint(equalToConstant: 38),
            commandProgressIndicator.leadingAnchor.constraint(equalTo: commandProgressContainer.leadingAnchor, constant: 12),
            commandProgressIndicator.centerYAnchor.constraint(equalTo: commandProgressContainer.centerYAnchor),
            commandProgressIndicator.widthAnchor.constraint(equalToConstant: 16),
            commandProgressIndicator.heightAnchor.constraint(equalToConstant: 16),
            commandProgressLineField.leadingAnchor.constraint(equalTo: commandProgressIndicator.trailingAnchor, constant: 10),
            commandProgressLineField.centerYAnchor.constraint(equalTo: commandProgressContainer.centerYAnchor),
            commandProgressLineField.trailingAnchor.constraint(equalTo: commandProgressSpaceField.leadingAnchor, constant: -12),
            commandProgressSpaceField.trailingAnchor.constraint(equalTo: commandProgressContainer.trailingAnchor, constant: -12),
            commandProgressSpaceField.centerYAnchor.constraint(equalTo: commandProgressContainer.centerYAnchor),
            commandProgressSpaceField.widthAnchor.constraint(equalToConstant: 132)
        ])

        selectionLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        selectionLabel.textColor = .secondaryLabelColor

        appSelector.controlSize = .regular
        appSelector.autoenablesItems = false

        selectionCountField.font = .systemFont(ofSize: 12)
        selectionCountField.textColor = .secondaryLabelColor

        selectionContainer.orientation = .horizontal
        selectionContainer.alignment = .centerY
        selectionContainer.spacing = 10
        selectionContainer.addArrangedSubview(selectionLabel)
        selectionContainer.addArrangedSubview(appSelector)
        selectionContainer.addArrangedSubview(selectionCountField)

        showCLIOutputButton.target = self
        showCLIOutputButton.action = #selector(toggleCLIOutput)
        showCLIOutputButton.state = .off
        showCLIOutputButton.controlSize = .regular

        operationEffectContainer.translatesAutoresizingMaskIntoConstraints = false
        operationEffectContainer.wantsLayer = true
        operationEffectContainer.layer?.cornerRadius = 8
        operationEffectContainer.layer?.backgroundColor = NSColor(calibratedRed: 0.06, green: 0.10, blue: 0.26, alpha: 0.85).cgColor
        operationEffectContainer.isHidden = true

        let effectView = NSHostingView(rootView: OperationEffectView(title: "Working", subtitle: "Preparing a safe operation."))
        effectView.translatesAutoresizingMaskIntoConstraints = false
        operationEffectContainer.addSubview(effectView)
        operationEffectView = effectView

        NSLayoutConstraint.activate([
            effectView.leadingAnchor.constraint(equalTo: operationEffectContainer.leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: operationEffectContainer.trailingAnchor),
            effectView.topAnchor.constraint(equalTo: operationEffectContainer.topAnchor),
            effectView.bottomAnchor.constraint(equalTo: operationEffectContainer.bottomAnchor),
            operationEffectContainer.heightAnchor.constraint(equalToConstant: 156)
        ])

        appSearchField.placeholderString = "Search apps"
        appSearchField.target = self
        appSearchField.action = #selector(appSearchChanged)
        appSearchField.sendsSearchStringImmediately = true

        appSortPopup.addItems(withTitles: AppSortMode.allCases.map(\.title))
        appSortPopup.selectItem(at: uninstallVM.sortMode.rawValue)
        appSortPopup.target = self
        appSortPopup.action = #selector(appSortChanged)

        appCatalogControls.orientation = .horizontal
        appCatalogControls.alignment = .centerY
        appCatalogControls.spacing = 10
        appCatalogControls.addArrangedSubview(appSearchField)
        appCatalogControls.addArrangedSubview(appSortPopup)
        appCatalogControls.translatesAutoresizingMaskIntoConstraints = false
        appCatalogControls.isHidden = true

        appInspectorView.translatesAutoresizingMaskIntoConstraints = false
        appInspectorView.isHidden = true
        appInspectorView.uninstallButton.target = self
        appInspectorView.uninstallButton.action = #selector(confirmPendingUninstall)
        appInspectorView.cancelButton.target = self
        appInspectorView.cancelButton.action = #selector(cancelPendingUninstall)
        appInspectorView.revealButton.target = self
        appInspectorView.revealButton.action = #selector(revealInspectedAppInFinder)

        previewTextView.isEditable = false
        previewTextView.isSelectable = true
        previewTextView.drawsBackground = false
        previewTextView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        previewTextView.textColor = .labelColor
        previewTextView.textContainerInset = NSSize(width: 0, height: 6)

        previewScrollView.borderType = .lineBorder
        previewScrollView.hasVerticalScroller = true
        previewScrollView.drawsBackground = false
        previewScrollView.documentView = previewTextView
        previewScrollView.translatesAutoresizingMaskIntoConstraints = false

        ambientCLIContainer.translatesAutoresizingMaskIntoConstraints = false
        ambientCLIContainer.wantsLayer = true
        ambientCLIContainer.isHidden = true
        let cliHost = NSHostingView(rootView: AmbientCLIView(lines: [], isRunning: false, placeholder: "Run a preview to inspect cleanup output before freeing space."))
        cliHost.translatesAutoresizingMaskIntoConstraints = false
        ambientCLIContainer.addSubview(cliHost)
        ambientCLIHostingView = cliHost
        NSLayoutConstraint.activate([
            cliHost.leadingAnchor.constraint(equalTo: ambientCLIContainer.leadingAnchor),
            cliHost.trailingAnchor.constraint(equalTo: ambientCLIContainer.trailingAnchor),
            cliHost.topAnchor.constraint(equalTo: ambientCLIContainer.topAnchor),
            cliHost.bottomAnchor.constraint(equalTo: ambientCLIContainer.bottomAnchor)
        ])

        appCatalogStack.orientation = .vertical
        appCatalogStack.alignment = .leading
        appCatalogStack.spacing = 12
        appCatalogStack.translatesAutoresizingMaskIntoConstraints = false
        appCatalogStack.isHidden = true

        appCatalogScrollView.hasVerticalScroller = true
        appCatalogScrollView.drawsBackground = false
        appCatalogScrollView.documentView = appCatalogStack
        appCatalogScrollView.translatesAutoresizingMaskIntoConstraints = false
        appCatalogScrollView.isHidden = true

        statusContainer.orientation = .horizontal
        statusContainer.alignment = .top
        statusContainer.distribution = .fillEqually
        statusContainer.spacing = 14

        detailContainer.orientation = .vertical
        detailContainer.alignment = .leading
        detailContainer.spacing = 10

        rootStack.addArrangedSubview(headerStack)
        rootStack.addArrangedSubview(actionStack)
        rootStack.addArrangedSubview(activityField)
        rootStack.addArrangedSubview(commandProgressContainer)
        rootStack.addArrangedSubview(selectionContainer)
        rootStack.addArrangedSubview(operationEffectContainer)
        rootStack.addArrangedSubview(appInspectorView)
        rootStack.addArrangedSubview(appCatalogControls)
        rootStack.addArrangedSubview(appCatalogStack)
        rootStack.addArrangedSubview(showCLIOutputButton)
        rootStack.addArrangedSubview(ambientCLIContainer)
        rootStack.addArrangedSubview(previewScrollView)
        rootStack.addArrangedSubview(statusContainer)
        rootStack.addArrangedSubview(detailContainer)

        contentDocumentView.addSubview(rootStack)
        view.addSubview(ambientBackgroundContainer)
        view.addSubview(contentScrollView)

        NSLayoutConstraint.activate([
            ambientBackgroundContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            ambientBackgroundContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            ambientBackgroundContainer.topAnchor.constraint(equalTo: view.topAnchor),
            ambientBackgroundContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ambientHost.leadingAnchor.constraint(equalTo: ambientBackgroundContainer.leadingAnchor),
            ambientHost.trailingAnchor.constraint(equalTo: ambientBackgroundContainer.trailingAnchor),
            ambientHost.topAnchor.constraint(equalTo: ambientBackgroundContainer.topAnchor),
            ambientHost.bottomAnchor.constraint(equalTo: ambientBackgroundContainer.bottomAnchor),
            contentScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentScrollView.topAnchor.constraint(equalTo: view.topAnchor),
            contentScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentDocumentView.leadingAnchor.constraint(equalTo: contentScrollView.contentView.leadingAnchor),
            contentDocumentView.trailingAnchor.constraint(equalTo: contentScrollView.contentView.trailingAnchor),
            contentDocumentView.topAnchor.constraint(equalTo: contentScrollView.contentView.topAnchor),
            contentDocumentView.bottomAnchor.constraint(equalTo: contentScrollView.contentView.bottomAnchor),
            contentDocumentView.widthAnchor.constraint(equalTo: contentScrollView.contentView.widthAnchor),
            rootStack.leadingAnchor.constraint(equalTo: contentDocumentView.leadingAnchor, constant: 36),
            rootStack.trailingAnchor.constraint(equalTo: contentDocumentView.trailingAnchor, constant: -36),
            rootStack.topAnchor.constraint(equalTo: contentDocumentView.topAnchor, constant: 34),
            rootStack.bottomAnchor.constraint(equalTo: contentDocumentView.bottomAnchor, constant: -36),
            appSearchField.widthAnchor.constraint(equalToConstant: 280),
            appSortPopup.widthAnchor.constraint(equalToConstant: 180),
            commandProgressContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 760),
            operationEffectContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 760),
            appCatalogControls.widthAnchor.constraint(greaterThanOrEqualToConstant: 760),
            appInspectorView.widthAnchor.constraint(greaterThanOrEqualToConstant: 760),
            appCatalogStack.widthAnchor.constraint(greaterThanOrEqualToConstant: 760),
            previewScrollView.widthAnchor.constraint(greaterThanOrEqualToConstant: 760),
            previewScrollView.heightAnchor.constraint(equalToConstant: 240),
            ambientCLIContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 760),
            ambientCLIContainer.heightAnchor.constraint(equalToConstant: 240),
            statusContainer.widthAnchor.constraint(greaterThanOrEqualToConstant: 760)
        ])
    }
}
