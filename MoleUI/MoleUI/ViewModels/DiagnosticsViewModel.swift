//
//  DiagnosticsViewModel.swift
//  Libella
//

import Foundation
import Observation

@Observable
final class DiagnosticsViewModel: ModuleViewModel {
    var outputText: String = ""
    var isRunning: Bool = false
    var statusMessage: String = "Ready. Run diagnostics against the bundled runtime."
    var onChange: (() -> Void)?

    private let commandRunner: MoleCommandRunning
    private var currentTask: MoleCommandTask?

    init(commandRunner: MoleCommandRunning) {
        self.commandRunner = commandRunner
    }

    func activate() {
        if outputText.isEmpty {
            statusMessage = "Ready. Run diagnostics against the bundled runtime."
        }
        notify()
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
        isRunning = false
        notify()
    }

    func runChecks() {
        currentTask?.cancel()
        isRunning = true
        statusMessage = "Checking bundled runtime version..."
        notify()

        currentTask = commandRunner.run(.version) { [weak self] result in
            guard let self else { return }
            self.currentTask = nil
            self.isRunning = false
            switch result {
            case .success(let r):
                self.outputText = r.stdout.strippingANSISequences()
                self.statusMessage = "Diagnostics complete."
            case .failure(let error):
                self.statusMessage = error.displayMessage
            }
            self.notify()
        }
    }

    private func notify() {
        onChange?()
    }
}
