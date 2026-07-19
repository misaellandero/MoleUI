//
//  UninstallViewModel.swift
//  Libella
//

import Foundation
import Observation

@Observable
final class UninstallViewModel: ModuleViewModel {
    var apps: [InstalledApp] = []
    var inspectedApp: InstalledApp?
    var pendingUninstallApp: InstalledApp?
    var pendingUninstallSummary: UninstallPreviewSummary?
    var previewOutput: String?
    var previewedAppName: String?
    var showCLIOutput: Bool = false
    var searchQuery: String = ""
    var sortMode: AppSortMode = .nameAscending
    var isRunning: Bool = false
    var statusMessage: String = "Ready. Load installed apps to begin."
    var renderGeneration: Int = 0
    var onChange: (() -> Void)?

    var onUninstallCompleted: ((InstalledApp, UninstallPreviewSummary?) -> Void)?

    var visibleApps: [InstalledApp] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = query.isEmpty ? apps : apps.filter {
            $0.name.localizedStandardContains(query)
                || $0.path.localizedStandardContains(query)
                || $0.bundleID.localizedStandardContains(query)
        }
        return filtered.sorted { a, b in
            switch sortMode {
            case .nameAscending:  return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            case .nameDescending: return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedDescending
            case .sizeDescending: return a.sizeInBytes > b.sizeInBytes
            case .sizeAscending:  return a.sizeInBytes < b.sizeInBytes
            }
        }
    }

    func app(for uninstallName: String) -> InstalledApp? {
        apps.first { $0.uninstallName == uninstallName }
    }

    private let resultProcessingQueue = DispatchQueue(
        label: "com.misaellandero.Libella.UninstallVM.resultProcessing",
        qos: .utility
    )
    private let commandRunner: MoleCommandRunning
    private var currentTask: MoleCommandTask?

    init(commandRunner: MoleCommandRunning) {
        self.commandRunner = commandRunner
    }

    func activate() {
        statusMessage = apps.isEmpty
            ? "Ready. Load installed apps to begin."
            : "Select an app for details, then uninstall from the top card."
        notify()
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
        isRunning = false
        statusMessage = "Cancellation requested."
        notify()
    }

    func loadApps(status: String) {
        currentTask?.cancel()
        isRunning = true
        statusMessage = status
        notify()

        let previousInspection = inspectedApp?.uninstallName
        currentTask = commandRunner.run(.uninstallList) { [weak self] result in
            guard let self else { return }
            self.currentTask = nil
            self.isRunning = false

            switch result {
            case .success(let r):
                let stdout = r.stdout
                self.statusMessage = "Processing installed apps..."
                self.notify()
                self.resultProcessingQueue.async { [weak self] in
                    guard let self else { return }
                    let decoded = Result { try JSONDecoder().decode([InstalledApp].self, from: Data(stdout.utf8)) }
                    DispatchQueue.main.async {
                        switch decoded {
                        case .success(let loadedApps):
                            self.apps = loadedApps
                            self.previewOutput = nil
                            self.previewedAppName = nil
                            self.pendingUninstallApp = nil
                            self.pendingUninstallSummary = nil
                            if let name = previousInspection, self.app(for: name) != nil {
                                self.inspectedApp = self.app(for: name)
                            } else {
                                self.inspectedApp = nil
                            }
                            self.statusMessage = "Loaded \(self.apps.count) installed apps."
                            self.renderGeneration += 1
                        case .failure(let error):
                            self.statusMessage = "Could not decode uninstall list: \(error.localizedDescription)"
                        }
                        self.notify()
                    }
                }
            case .failure(let error):
                self.statusMessage = error.displayMessage
                self.notify()
            }
        }
    }

    func selectApp(_ app: InstalledApp, showConfirmation: Bool) {
        inspectedApp = app
        previewedAppName = nil
        previewOutput = nil
        pendingUninstallApp = showConfirmation ? app : nil
        pendingUninstallSummary = nil
        notify()
        prepareUninstallSummary(for: app, showConfirmation: showConfirmation)
    }

    func prepareUninstallSummary(for app: InstalledApp, showConfirmation: Bool) {
        let status = showConfirmation
            ? "Preparing uninstall summary for \(app.name)..."
            : "Inspecting \(app.name)..."
        currentTask?.cancel()
        isRunning = true
        statusMessage = status
        notify()

        currentTask = commandRunner.run(
            .uninstallDryRun(appName: app.uninstallName),
            outputHandler: nil
        ) { [weak self] result in
            guard let self else { return }
            self.currentTask = nil
            self.isRunning = false

            switch result {
            case .success(let r):
                let stdout = r.stdout
                self.resultProcessingQueue.async { [weak self] in
                    guard let self else { return }
                    let cleaned = stdout.strippingANSISequences()
                    let summary = UninstallPreviewSummary.parse(from: cleaned, fallbackSize: app.size)
                    DispatchQueue.main.async {
                        guard self.inspectedApp?.uninstallName == app.uninstallName else { return }
                        self.previewOutput = cleaned
                        self.previewedAppName = app.uninstallName
                        self.pendingUninstallApp = showConfirmation ? app : nil
                        self.pendingUninstallSummary = summary
                        self.statusMessage = showConfirmation
                            ? "Ready to uninstall \(app.name). Review the summary, then confirm."
                            : "Inspector ready for \(app.name)."
                        self.notify()
                    }
                }
            case .failure(let error):
                self.statusMessage = error.displayMessage
                self.notify()
            }
        }
    }

    func executeUninstall(app: InstalledApp, expectedSummary: UninstallPreviewSummary?) {
        currentTask?.cancel()
        isRunning = true
        statusMessage = "Uninstalling \(app.name)..."
        notify()

        currentTask = commandRunner.run(
            .uninstall(appName: app.uninstallName),
            outputHandler: nil
        ) { [weak self] result in
            guard let self else { return }
            self.currentTask = nil
            self.isRunning = false

            switch result {
            case .success(let r):
                let stdout = r.stdout
                self.resultProcessingQueue.async { [weak self] in
                    guard let self else { return }
                    let cleaned = stdout.strippingANSISequences()
                    DispatchQueue.main.async {
                        self.previewOutput = cleaned
                        self.previewedAppName = app.uninstallName
                        self.pendingUninstallApp = nil
                        self.pendingUninstallSummary = nil
                        self.onUninstallCompleted?(app, expectedSummary)
                        self.statusMessage = "Uninstall finished for \(app.name). Refreshing app list..."
                        self.notify()
                        self.loadApps(status: "Refreshing installed apps after uninstall...")
                    }
                }
            case .failure(let error):
                self.statusMessage = error.displayMessage
                self.notify()
            }
        }
    }

    private func notify() {
        onChange?()
    }
}
