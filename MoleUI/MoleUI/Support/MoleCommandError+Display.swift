//
//  MoleCommandError+Display.swift
//  Libella
//

import Foundation

extension MoleCommandError {
    var displayMessage: String {
        switch self {
        case .missingBinary:
            return "Bundled runtime was not found. Check the app bundle resources."
        case .launchFailed(let message):
            return "Command could not start: \(message)"
        case .permissionDenied(let message):
            return "Command was blocked by permissions: \(message)"
        case .cancelled:
            return "Command was cancelled."
        case .timedOut(let timeout):
            let minutes = max(1, Int(ceil(timeout / 60)))
            return "Operation stopped after \(minutes) minutes to keep the Mac responsive. Review the latest status, then try again with Full Disk Access if needed."
        case .nonZeroExit(let result):
            let detail = result.stderr.isEmpty ? result.stdout : result.stderr
            let firstLine = detail.split(separator: "\n").first.map(String.init) ?? "No error detail was returned."
            return "Command exited with code \(result.exitCode): \(firstLine)"
        }
    }
}
