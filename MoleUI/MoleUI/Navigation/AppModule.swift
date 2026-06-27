//
//  AppModule.swift
//  Libella
//

import Foundation

enum AppModule: String, CaseIterable {
    case overview
    case clean
    case uninstall
    case history
    case diagnostics

    static var allCases: [AppModule] {
        [.overview, .clean, .uninstall, .diagnostics]
    }

    var title: String {
        switch self {
        case .overview:
            return "Overview"
        case .clean:
            return "Clean"
        case .uninstall:
            return "Uninstall"
        case .history:
            return "History"
        case .diagnostics:
            return "Diagnostics"
        }
    }

    var subtitle: String {
        switch self {
        case .overview:
            return "Disk pressure, health, and next cleanup actions."
        case .clean:
            return "Preview and free reclaimable space without blocking on sudo."
        case .uninstall:
            return "Review installed apps, preview leftover removal, and uninstall safely."
        case .history:
            return "Review dry runs, cleanup results, and operation logs."
        case .diagnostics:
            return "Verify setup, permissions, and common integration issues."
        }
    }

    var symbolName: String {
        switch self {
        case .overview:
            return "gauge.with.dots.needle.67percent"
        case .clean:
            return "sparkles"
        case .uninstall:
            return "rectangle.stack.badge.minus"
        case .history:
            return "clock.arrow.circlepath"
        case .diagnostics:
            return "stethoscope"
        }
    }

    var placeholderMessage: String {
        switch self {
        case .overview:
            return "Optimization checklist is preparing the first recommendations."
        case .clean:
            return "Run a clean preview to see reclaimable space before removal."
        case .uninstall:
            return "Load installed apps, preview one, then confirm uninstall."
        case .history:
            return "History loading will read operation logs in the next milestone."
        case .diagnostics:
            return "Diagnostics will check CLI availability without hidden authorization prompts."
        }
    }

    var busyTitle: String {
        switch self {
        case .overview:
            return "Scanning your Mac"
        case .clean:
            return "Cleaning safely"
        case .uninstall:
            return "Preparing apps"
        case .diagnostics:
            return "Checking setup"
        default:
            return "Working"
        }
    }

    var busySubtitle: String {
        switch self {
        case .overview:
            return "Checking cleanup opportunities and app inventory. You can keep this view open while the scan runs."
        case .clean:
            return "Scanning and applying cleanup through the bundled runtime."
        case .uninstall:
            return "Loading, previewing, or removing app files with safety checks enabled."
        case .diagnostics:
            return "Verifying the bundled runtime without hidden escalation."
        default:
            return "This operation is running off the main thread."
        }
    }
}
