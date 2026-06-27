//
//  OverviewViewModel.swift
//  Libella
//

import Foundation
import Observation

@Observable
final class OverviewViewModel: ModuleViewModel {
    var diskSpaceSummary: DiskSpaceSummary = DiskSpaceSummary.load()
    var cleanPreviewSummary: CleanPreviewSummary?
    var cleanPreviewOutput: String?
    var spaceCelebrationID: Int = 0
    var isRunning: Bool = false
    var uninstallAppCount: Int = 0
    var statusMessage: String = "Ready. Start a scan when you want to inspect protected app data."
    var onChange: (() -> Void)?

    private var liveDiskRefreshTimer: Timer?
    private let diskRefreshQueue = DispatchQueue(
        label: "com.misaellandero.Libella.OverviewVM.diskRefresh",
        qos: .utility
    )
    private let commandRunner: MoleCommandRunning
    private var currentTask: MoleCommandTask?

    init(commandRunner: MoleCommandRunning) {
        self.commandRunner = commandRunner
    }

    func activate() {
        diskSpaceSummary = DiskSpaceSummary.load()
        statusMessage = "Ready. Start a scan when you want to inspect protected app data."
        notify()
    }

    func deactivate() {
        currentTask?.cancel()
        currentTask = nil
        stopLiveDiskRefresh()
        isRunning = false
    }

    func cancel() {
        deactivate()
        statusMessage = "Cancellation requested."
        notify()
    }

    func runScan(status: String) {
        currentTask?.cancel()
        isRunning = true
        statusMessage = status
        startLiveDiskRefresh()
        notify()

        currentTask = commandRunner.run(
            .cleanDryRun,
            outputHandler: nil
        ) { [weak self] result in
            guard let self else { return }
            self.currentTask = nil
            self.isRunning = false
            self.stopLiveDiskRefresh()
            self.refreshDiskSpace()

            switch result {
            case .success(let r):
                let stdout = r.stdout
                do {
                    let report = try JSONDecoder().decode(CleanPreviewReport.self, from: Data(stdout.utf8))
                    let summary = CleanPreviewSummary(report: report)
                    self.cleanPreviewOutput = report.previewText
                    self.cleanPreviewSummary = summary
                    self.statusMessage = summary.statusLine
                } catch {
                    self.cleanPreviewOutput = stdout.strippingANSISequences()
                    self.cleanPreviewSummary = nil
                    self.statusMessage = "Could not decode overview scan."
                }
            case .failure(let error):
                self.statusMessage = error.displayMessage
            }
            self.notify()
        }
    }

    func acceptCleanResult(summary: CleanPreviewSummary?, freedBytes: Int64?) {
        cleanPreviewSummary = summary
        spaceCelebrationID += 1
        refreshDiskSpace()
        notify()
    }

    func acceptUninstallCount(_ count: Int) {
        uninstallAppCount = count
        notify()
    }

    func refreshDiskSpace() {
        diskRefreshQueue.async { [weak self] in
            let summary = DiskSpaceSummary.load()
            DispatchQueue.main.async {
                guard let self else { return }
                self.diskSpaceSummary = summary
                self.notify()
            }
        }
    }

    private func startLiveDiskRefresh() {
        guard liveDiskRefreshTimer == nil else { return }
        refreshDiskSpace()
        liveDiskRefreshTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.refreshDiskSpace()
        }
    }

    private func stopLiveDiskRefresh() {
        liveDiskRefreshTimer?.invalidate()
        liveDiskRefreshTimer = nil
    }

    private func notify() {
        onChange?()
    }
}
