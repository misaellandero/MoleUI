//
//  CleanViewModel.swift
//  Libella
//

import Foundation
import Observation

@Observable
final class CleanViewModel: ModuleViewModel {
    var previewOutput: String?
    var previewSummary: CleanPreviewSummary?
    var showCLIOutput: Bool = false
    var isRunning: Bool = false
    var statusMessage: String = "Ready. Preview cleanup before removing files."
    var progressDisplayedBytes: Int64 = 0
    var progressTargetBytes: Int64 = 0
    var lastProgressLine: String = "Waiting for command output..."
    var progressLineIsError: Bool = false
    var streamingOutput: String = ""
    var onChange: (() -> Void)?

    // Called by the coordinator after a successful clean so Overview can update.
    var onCleanCompleted: ((CleanPreviewSummary?, Int64?) -> Void)?

    private let resultProcessingQueue = DispatchQueue(
        label: "com.misaellandero.Libella.CleanVM.resultProcessing",
        qos: .utility
    )
    private let commandRunner: MoleCommandRunning
    private var currentTask: MoleCommandTask?
    private var lastProgressLineUpdate = Date.distantPast

    init(commandRunner: MoleCommandRunning) {
        self.commandRunner = commandRunner
    }

    func activate() {
        statusMessage = previewSummary == nil
            ? "Ready. Preview cleanup before removing files."
            : "Preview ready. Confirm before freeing space."
        notify()
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
        isRunning = false
        statusMessage = "Cancellation requested."
        notify()
    }

    func runPreview(status: String) {
        currentTask?.cancel()
        isRunning = true
        progressDisplayedBytes = 0
        progressTargetBytes = 0
        lastProgressLine = status
        lastProgressLineUpdate = .distantPast
        streamingOutput = ""
        statusMessage = status
        notify()

        currentTask = commandRunner.run(
            .cleanDryRun,
            outputHandler: { [weak self] output in
                self?.handleOutput(output)
            }
        ) { [weak self] result in
            guard let self else { return }
            self.currentTask = nil
            self.isRunning = false

            switch result {
            case .success(let r):
                let stdout = r.stdout
                self.statusMessage = "Processing clean preview..."
                self.notify()
                self.resultProcessingQueue.async { [weak self] in
                    guard let self else { return }
                    let (text, summary, failure) = Self.decodePreview(stdout: stdout)
                    DispatchQueue.main.async {
                        if let text, let summary {
                            self.previewOutput = text
                            self.previewSummary = summary
                            self.statusMessage = summary.statusLine
                            if let bytes = summary.potentialSpaceBytes {
                                self.animateProgressBytes(to: bytes)
                            }
                        } else {
                            self.previewOutput = text
                            self.previewSummary = nil
                            self.statusMessage = failure ?? "Could not decode clean preview."
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

    // The ViewController calls this after showing the NSAlert confirmation.
    func executeClean(expectedSummary: CleanPreviewSummary?) {
        currentTask?.cancel()
        isRunning = true
        lastProgressLine = "Freeing space..."
        lastProgressLineUpdate = .distantPast
        statusMessage = "Freeing space..."
        notify()

        let expectedBytes = expectedSummary?.potentialSpaceBytes
        streamingOutput = ""

        currentTask = commandRunner.run(
            .cleanRun,
            outputHandler: { [weak self] output in
                self?.handleOutput(output)
            }
        ) { [weak self] result in
            guard let self else { return }
            self.currentTask = nil
            self.isRunning = false

            switch result {
            case .success(let r):
                let stdout = r.stdout
                self.statusMessage = "Processing cleanup result..."
                self.notify()
                self.resultProcessingQueue.async { [weak self] in
                    guard let self else { return }
                    let cleaned = stdout.strippingANSISequences()
                    let summary = CleanPreviewSummary.parse(from: cleaned)
                    DispatchQueue.main.async {
                        self.previewOutput = cleaned
                        self.previewSummary = summary
                        let freedBytes = summary?.potentialSpaceBytes ?? expectedBytes
                        if let freedBytes {
                            self.animateProgressBytes(to: freedBytes)
                        }
                        self.statusMessage = summary?.statusLine ?? "Cleanup completed."
                        self.onCleanCompleted?(summary, freedBytes)
                        self.notify()
                    }
                }
            case .failure(let error):
                self.statusMessage = error.displayMessage
                self.notify()
            }
        }
    }

    func animateProgressBytes(to target: Int64) {
        let start = progressDisplayedBytes
        progressTargetBytes = target
        let generation = target
        let steps = 21
        for step in 1...steps {
            let delay = 0.7 * Double(step) / Double(steps)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.progressTargetBytes == generation else { return }
                let p = Self.easeOutCubic(Double(step) / Double(steps))
                self.progressDisplayedBytes = start + Int64(Double(target - start) * p)
                self.onChange?()
            }
        }
    }

    private func handleOutput(_ output: MoleCommandOutput) {
        let cleanText = output.text.strippingANSISequences()
        if !cleanText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            streamingOutput += cleanText
            notify()
        }
        if let line = CommandOutputParser.compactProgressLine(from: cleanText) {
            let now = Date()
            let isError = output.stream == .stderr
            if now.timeIntervalSince(lastProgressLineUpdate) > 0.08 || isError {
                lastProgressLineUpdate = now
                lastProgressLine = line
                progressLineIsError = isError
                notify()
            }
        }
        if let bytes = CommandOutputParser.largestStorageValue(in: cleanText), bytes > progressTargetBytes {
            animateProgressBytes(to: bytes)
        }
    }

    private static func decodePreview(stdout: String) -> (text: String?, summary: CleanPreviewSummary?, failure: String?) {
        do {
            let report = try JSONDecoder().decode(CleanPreviewReport.self, from: Data(stdout.utf8))
            return (report.previewText, CleanPreviewSummary(report: report), nil)
        } catch {
            return (stdout.strippingANSISequences(), nil, "Could not decode clean preview JSON: \(error.localizedDescription)")
        }
    }

    private static func easeOutCubic(_ t: Double) -> Double {
        1 - pow(1 - t, 3)
    }

    private func notify() {
        onChange?()
    }
}
