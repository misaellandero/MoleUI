//
//  MoleCommandRunner.swift
//  Libella
//
//  Created by Misael Landero on 02/06/26.
//

import Foundation

nonisolated struct MoleCommandRequest: Equatable {
    private enum DefaultTimeouts {
        static let quick: TimeInterval = 30
        static let version: TimeInterval = 10
        static let scan: TimeInterval = 300
        static let destructive: TimeInterval = 900
    }

    var arguments: [String]
    var timeout: TimeInterval
    var environment: [String: String]
    var stdinText: String?

    init(arguments: [String], timeout: TimeInterval = DefaultTimeouts.quick, environment: [String: String] = [:], stdinText: String? = nil) {
        self.arguments = arguments
        self.timeout = timeout
        self.environment = environment
        self.stdinText = stdinText
    }

    static var version: MoleCommandRequest {
        MoleCommandRequest(arguments: ["--version"], timeout: DefaultTimeouts.version)
    }

    static var cleanDryRun: MoleCommandRequest {
        MoleCommandRequest(
            arguments: ["clean", "--dry-run", "--json"],
            timeout: DefaultTimeouts.scan,
            environment: [
                "MOLE_TEST_NO_AUTH": "1",
                "MOLE_DRY_RUN": "1"
            ]
        )
    }

    static var cleanRun: MoleCommandRequest {
        MoleCommandRequest(
            arguments: ["clean"],
            timeout: DefaultTimeouts.destructive,
            environment: [
                "MOLE_TEST_NO_AUTH": "1"
            ]
        )
    }

    static var uninstallList: MoleCommandRequest {
        MoleCommandRequest(arguments: ["uninstall", "--list"], timeout: DefaultTimeouts.scan)
    }

    static func uninstallDryRun(appName: String) -> MoleCommandRequest {
        MoleCommandRequest(
            arguments: ["uninstall", "--dry-run", appName],
            timeout: DefaultTimeouts.scan,
            environment: [
                "MOLE_TEST_NO_AUTH": "1",
                "MOLE_DRY_RUN": "1"
            ],
            stdinText: "y\n"
        )
    }

    static func uninstall(appName: String) -> MoleCommandRequest {
        MoleCommandRequest(
            arguments: ["uninstall", appName],
            timeout: DefaultTimeouts.destructive,
            environment: [
                "MOLE_TEST_NO_AUTH": "1"
            ],
            stdinText: "y\n"
        )
    }
}

nonisolated struct MoleCommandResult: Equatable {
    let executableURL: URL
    let arguments: [String]
    let stdout: String
    let stderr: String
    let exitCode: Int32
}

nonisolated struct MoleCommandOutput {
    enum Stream {
        case stdout
        case stderr
    }

    let stream: Stream
    let text: String
}

nonisolated enum MoleCommandError: Error, Equatable {
    case missingBinary
    case launchFailed(String)
    case permissionDenied(String)
    case cancelled
    case timedOut(TimeInterval)
    case nonZeroExit(MoleCommandResult)
}

protocol MoleCommandRunning {
    @discardableResult
    func run(
        _ request: MoleCommandRequest,
        outputHandler: ((MoleCommandOutput) -> Void)?,
        completion: @escaping (Result<MoleCommandResult, MoleCommandError>) -> Void
    ) -> MoleCommandTask
}

extension MoleCommandRunning {
    @discardableResult
    func run(_ request: MoleCommandRequest, completion: @escaping (Result<MoleCommandResult, MoleCommandError>) -> Void) -> MoleCommandTask {
        run(request, outputHandler: nil, completion: completion)
    }
}

final class MoleCommandTask {
    enum CancellationReason {
        case user
        case timeout
    }

    private let lock = NSLock()
    private var process: Process?
    private var cancellationReason: CancellationReason?

    func attach(process: Process) {
        lock.lock()
        self.process = process
        let shouldTerminate = cancellationReason != nil
        lock.unlock()

        if shouldTerminate, process.isRunning {
            process.terminate()
        }
    }

    func cancel() {
        cancel(reason: .user)
    }

    func cancel(reason: CancellationReason) {
        lock.lock()
        if cancellationReason == nil {
            cancellationReason = reason
        }
        let process = process
        lock.unlock()

        if process?.isRunning == true {
            process?.terminate()
        }
    }

    var reason: CancellationReason? {
        lock.lock()
        defer { lock.unlock() }
        return cancellationReason
    }
}

final class MoleBinaryLocator {
    private let fileManager: FileManager
    private let userDefaults: UserDefaults

    init(fileManager: FileManager = .default, userDefaults: UserDefaults = .standard) {
        self.fileManager = fileManager
        self.userDefaults = userDefaults
    }

    func locate() -> URL? {
        bundledURL() ?? configuredURL() ?? pathURL() ?? developmentURL()
    }

    private func configuredURL() -> URL? {
        guard let path = userDefaults.string(forKey: "MoleBinaryPath"), !path.isEmpty else {
            return nil
        }
        return executableURL(path)
    }

    private func bundledURL() -> URL? {
        guard let resourceURL = Bundle.main.resourceURL else {
            return nil
        }
        return executableURL(resourceURL.appendingPathComponent("mo").path)
    }

    private func pathURL() -> URL? {
        let candidates = [
            "/opt/homebrew/bin/mo",
            "/usr/local/bin/mo",
            "/usr/bin/mo"
        ]
        return candidates.lazy.compactMap(executableURL).first
    }

    private func developmentURL() -> URL? {
        var directory = Bundle.main.bundleURL.deletingLastPathComponent()
        for _ in 0..<8 {
            let candidate = directory.appendingPathComponent("mo")
            if isExecutable(candidate.path) {
                return candidate
            }
            directory.deleteLastPathComponent()
        }
        return nil
    }

    private func executableURL(_ path: String) -> URL? {
        isExecutable(path) ? URL(fileURLWithPath: path) : nil
    }

    private func isExecutable(_ path: String) -> Bool {
        fileManager.isExecutableFile(atPath: path)
    }
}

final class MoleCommandRunner: MoleCommandRunning {
    private let binaryLocator: MoleBinaryLocator
    private let queue: DispatchQueue
    private let timeoutQueue: DispatchQueue

    init(
        binaryLocator: MoleBinaryLocator = MoleBinaryLocator(),
        queue: DispatchQueue = DispatchQueue(label: "com.misaellandero.Libella.MoleCommandRunner", qos: .utility),
        timeoutQueue: DispatchQueue = DispatchQueue(label: "com.misaellandero.Libella.MoleCommandRunner.timeout", qos: .utility)
    ) {
        self.binaryLocator = binaryLocator
        self.queue = queue
        self.timeoutQueue = timeoutQueue
    }

    @discardableResult
    func run(
        _ request: MoleCommandRequest,
        outputHandler: ((MoleCommandOutput) -> Void)?,
        completion: @escaping (Result<MoleCommandResult, MoleCommandError>) -> Void
    ) -> MoleCommandTask {
        let task = MoleCommandTask()
        queue.async { [binaryLocator] in
            guard let executableURL = binaryLocator.locate() else {
                DispatchQueue.main.async {
                    completion(.failure(.missingBinary))
                }
                return
            }

            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            let inputPipe = Pipe()
            let outputBuffer = LockedDataBuffer()
            let errorBuffer = LockedDataBuffer()
            let launch = Self.lowPriorityLaunch(executableURL: executableURL, arguments: request.arguments)

            process.executableURL = launch.executableURL
            process.arguments = launch.arguments
            process.qualityOfService = .utility
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            process.standardInput = inputPipe
            process.environment = Self.environment(overrides: request.environment)
            task.attach(process: process)

            if let reason = task.reason {
                DispatchQueue.main.async {
                    completion(.failure(reason == .timeout ? .timedOut(request.timeout) : .cancelled))
                }
                return
            }

            let timeoutSource = DispatchSource.makeTimerSource(queue: self.timeoutQueue)
            timeoutSource.schedule(deadline: .now() + request.timeout)
            timeoutSource.setEventHandler {
                if process.isRunning {
                    task.cancel(reason: .timeout)
                }
            }
            timeoutSource.resume()

            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                outputBuffer.append(data)
                Self.emitOutput(data, stream: .stdout, outputHandler: outputHandler)
            }
            errorPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                errorBuffer.append(data)
                Self.emitOutput(data, stream: .stderr, outputHandler: outputHandler)
            }

            do {
                try process.run()
                if let stdinText = request.stdinText {
                    if let data = stdinText.data(using: .utf8) {
                        inputPipe.fileHandleForWriting.write(data)
                    }
                    try? inputPipe.fileHandleForWriting.close()
                }
            } catch {
                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil
                timeoutSource.cancel()
                DispatchQueue.main.async {
                    completion(.failure(Self.launchError(from: error)))
                }
                return
            }

            process.waitUntilExit()
            timeoutSource.cancel()
            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
            outputBuffer.append(outputPipe.fileHandleForReading.readDataToEndOfFile())
            errorBuffer.append(errorPipe.fileHandleForReading.readDataToEndOfFile())

            let result = MoleCommandResult(
                executableURL: executableURL,
                arguments: request.arguments,
                stdout: outputBuffer.stringValue,
                stderr: errorBuffer.stringValue,
                exitCode: process.terminationStatus
            )

            DispatchQueue.main.async {
                if let reason = task.reason {
                    switch reason {
                    case .user:
                        completion(.failure(.cancelled))
                    case .timeout:
                        completion(.failure(.timedOut(request.timeout)))
                    }
                } else if result.exitCode != 0 {
                    completion(.failure(.nonZeroExit(result)))
                } else {
                    completion(.success(result))
                }
            }
        }
        return task
    }

    private static func environment(overrides: [String: String]) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        overrides.forEach { key, value in
            environment[key] = value
        }
        return environment
    }

    private static func lowPriorityLaunch(executableURL: URL, arguments: [String]) -> (executableURL: URL, arguments: [String]) {
        let niceURL = URL(fileURLWithPath: "/usr/bin/nice")
        guard FileManager.default.isExecutableFile(atPath: niceURL.path) else {
            return (executableURL, arguments)
        }
        return (niceURL, ["-n", "10", executableURL.path] + arguments)
    }

    private static func emitOutput(
        _ data: Data,
        stream: MoleCommandOutput.Stream,
        outputHandler: ((MoleCommandOutput) -> Void)?
    ) {
        guard
            let outputHandler,
            !data.isEmpty,
            let text = String(data: data, encoding: .utf8),
            !text.isEmpty
        else {
            return
        }

        DispatchQueue.main.async {
            outputHandler(MoleCommandOutput(stream: stream, text: text))
        }
    }

    private static func launchError(from error: Error) -> MoleCommandError {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileReadNoPermissionError {
            return .permissionDenied(nsError.localizedDescription)
        }
        if nsError.domain == NSPOSIXErrorDomain && nsError.code == Int(EACCES) {
            return .permissionDenied(nsError.localizedDescription)
        }
        return .launchFailed(nsError.localizedDescription)
    }

}

private final class LockedDataBuffer {
    private let lock = NSLock()
    private var data = Data()

    func append(_ newData: Data) {
        guard !newData.isEmpty else {
            return
        }
        lock.lock()
        data.append(newData)
        lock.unlock()
    }

    var stringValue: String {
        lock.lock()
        let snapshot = data
        lock.unlock()
        return String(data: snapshot, encoding: .utf8) ?? ""
    }
}
