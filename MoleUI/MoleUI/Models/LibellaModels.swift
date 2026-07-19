//
//  LibellaModels.swift
//  Libella
//

import Cocoa

nonisolated struct CleanPreviewSummary {
    let potentialSpace: String
    let potentialSpaceKB: Int?
    let itemCount: String
    let categoryCount: String

    var statusLine: String {
        "Preview complete. Potential space: \(potentialSpace), Items: \(itemCount), Categories: \(categoryCount)."
    }

    var potentialSpaceBytes: Int64? {
        if let potentialSpaceKB {
            return Int64(potentialSpaceKB) * 1024
        }
        return StorageSizeParser.bytes(from: potentialSpace)
    }

    init(potentialSpace: String, itemCount: String, categoryCount: String) {
        self.potentialSpace = potentialSpace
        self.potentialSpaceKB = nil
        self.itemCount = itemCount
        self.categoryCount = categoryCount
    }

    init(report: CleanPreviewReport) {
        potentialSpace = report.summary.estimatedSize
        potentialSpaceKB = report.summary.estimatedSizeKB
        itemCount = "\(report.summary.items)"
        categoryCount = "\(report.summary.categories)"
    }

    static func parse(from output: String) -> CleanPreviewSummary? {
        let patterns = [
            #"Potential space:\s*([^\|]+)\|\s*Items:\s*([0-9]+)\s*\|\s*Categories:\s*([0-9]+)"#,
            #"Tracked cleanup:\s*([^\|]+)\|\s*Items cleaned:\s*([0-9]+)\s*\|\s*Categories:\s*([0-9]+)"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                continue
            }
            guard
                let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
                let spaceRange = Range(match.range(at: 1), in: output),
                let itemRange = Range(match.range(at: 2), in: output),
                let categoryRange = Range(match.range(at: 3), in: output)
            else {
                continue
            }

            return CleanPreviewSummary(
                potentialSpace: output[spaceRange].trimmingCharacters(in: .whitespacesAndNewlines),
                itemCount: String(output[itemRange]),
                categoryCount: String(output[categoryRange])
            )
        }

        return nil
    }
}

nonisolated struct DiskVolumeSummary: Identifiable, Equatable {
    let id: String
    let name: String
    let availableBytes: Int64
    let totalBytes: Int64

    var usedFraction: Double {
        guard totalBytes > 0 else {
            return 0
        }
        let used = max(0, totalBytes - availableBytes)
        return min(1, Double(used) / Double(totalBytes))
    }
}

nonisolated struct DiskSpaceSummary: Equatable {
    let volumes: [DiskVolumeSummary]

    var availableBytes: Int64 {
        volumes.reduce(0) { $0 + $1.availableBytes }
    }

    var totalBytes: Int64 {
        volumes.reduce(0) { $0 + $1.totalBytes }
    }

    var availableText: String {
        ByteCountFormatter.storageString(from: availableBytes)
    }

    var totalText: String {
        ByteCountFormatter.storageString(from: totalBytes)
    }

    static func load() -> DiskSpaceSummary {
        let keys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey
        ]

        let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: [.skipHiddenVolumes]
        ) ?? [URL(fileURLWithPath: "/")]

        var seen = Set<String>()
        let volumes = urls.compactMap { url -> DiskVolumeSummary? in
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else {
                return nil
            }
            let total = Int64(values.volumeTotalCapacity ?? 0)
            let available = values.volumeAvailableCapacityForImportantUsage ?? 0
            guard total > 0, available >= 0 else {
                return nil
            }
            let id = url.path
            guard seen.insert(id).inserted else {
                return nil
            }
            let name = values.volumeName?.isEmpty == false ? values.volumeName! : url.lastPathComponent
            return DiskVolumeSummary(id: id, name: name, availableBytes: available, totalBytes: total)
        }

        return DiskSpaceSummary(volumes: volumes)
    }
}

nonisolated struct CleanupStatsStore: Codable, Equatable {
    private static let defaultsKey = "cleanup.stats.v1"

    var totalFreedBytes: Int64
    var uninstalledAppCount: Int
    var cleanRunCount: Int
    var recentApps: [String]

    var totalFreedText: String {
        ByteCountFormatter.storageString(from: totalFreedBytes)
    }

    static func load() -> CleanupStatsStore {
        guard
            let data = UserDefaults.standard.data(forKey: defaultsKey),
            let stats = try? JSONDecoder().decode(CleanupStatsStore.self, from: data)
        else {
            return CleanupStatsStore(totalFreedBytes: 0, uninstalledAppCount: 0, cleanRunCount: 0, recentApps: [])
        }
        return stats
    }

    mutating func recordClean(freedBytes: Int64?) {
        cleanRunCount += 1
        totalFreedBytes += max(0, freedBytes ?? 0)
        save()
    }

    mutating func recordUninstall(appName: String, freedBytes: Int64?) {
        uninstalledAppCount += 1
        totalFreedBytes += max(0, freedBytes ?? 0)
        recentApps.removeAll { $0 == appName }
        recentApps.insert(appName, at: 0)
        recentApps = Array(recentApps.prefix(5))
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(self) else {
            return
        }
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
    }
}

nonisolated extension ByteCountFormatter {
    static func storageString(from bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useTB, .useMB]
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: bytes)
    }
}

enum VisualSettings {
    private static let particlesKey = "visual.particles.enabled"
    private static let tronLinesKey = "visual.tronLines.enabled"

    static var particlesEnabled: Bool {
        get {
            UserDefaults.standard.object(forKey: particlesKey) as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: particlesKey)
            NotificationCenter.default.post(name: .visualSettingsChanged, object: nil)
        }
    }

    static var tronLinesEnabled: Bool {
        get {
            UserDefaults.standard.object(forKey: tronLinesKey) as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: tronLinesKey)
            NotificationCenter.default.post(name: .visualSettingsChanged, object: nil)
        }
    }
}

enum PrivacyPromptPolicy {
    private static let accessGuideKey = "privacy.accessGuideShown.v1"

    static var didShowAccessGuide: Bool {
        get {
            UserDefaults.standard.bool(forKey: accessGuideKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: accessGuideKey)
        }
    }

    static func openFullDiskAccessSettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles",
            "x-apple.systempreferences:com.apple.preference.security?Privacy"
        ]

        for value in urls {
            guard let url = URL(string: value) else {
                continue
            }
            if NSWorkspace.shared.open(url) {
                return
            }
        }
    }
}

extension Notification.Name {
    static let visualSettingsChanged = Notification.Name("visualSettingsChanged")
}

nonisolated enum StorageSizeParser {
    static func bytes(from text: String) -> Int64? {
        let normalized = text
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            let regex = try? NSRegularExpression(pattern: #"([0-9]+(?:\.[0-9]+)?)\s*([KMGT]?I?B|bytes?)"#, options: [.caseInsensitive]),
            let match = regex.firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized)),
            let valueRange = Range(match.range(at: 1), in: normalized),
            let unitRange = Range(match.range(at: 2), in: normalized),
            let value = Double(normalized[valueRange])
        else {
            return nil
        }

        let unit = normalized[unitRange].lowercased()
        let multiplier: Double
        switch unit {
        case "kb", "kib":
            multiplier = 1024
        case "mb", "mib":
            multiplier = 1024 * 1024
        case "gb", "gib":
            multiplier = 1024 * 1024 * 1024
        case "tb", "tib":
            multiplier = 1024 * 1024 * 1024 * 1024
        default:
            multiplier = 1
        }

        return Int64(value * multiplier)
    }
}

nonisolated struct CleanPreviewReport: Codable, Equatable {
    let schemaVersion: Int
    let command: String
    let status: String
    let dryRun: Bool
    let summary: Summary
    let categories: [Category]
    let warnings: [String]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case command
        case status
        case dryRun = "dry_run"
        case summary
        case categories
        case warnings
    }

    struct Summary: Codable, Equatable {
        let estimatedSizeKB: Int
        let estimatedSize: String
        let items: Int
        let categories: Int
        let whitelistSkipped: Int
        let exportListFile: String?

        enum CodingKeys: String, CodingKey {
            case estimatedSizeKB = "estimated_size_kb"
            case estimatedSize = "estimated_size"
            case items
            case categories
            case whitelistSkipped = "whitelist_skipped"
            case exportListFile = "export_list_file"
        }
    }

    struct Category: Codable, Equatable {
        let section: String
        let label: String
        let sizeKB: Int
        let size: String
        let items: Int

        enum CodingKeys: String, CodingKey {
            case section
            case label
            case sizeKB = "size_kb"
            case size
            case items
        }
    }

    var previewText: String {
        var lines = [
            "Clean preview",
            "",
            "Potential space: \(summary.estimatedSize)",
            "Items: \(summary.items)",
            "Categories: \(summary.categories)"
        ]

        if let exportListFile = summary.exportListFile {
            lines.append("Detailed file list: \(exportListFile)")
        }

        if !categories.isEmpty {
            lines.append("")
            lines.append("Categories")
            categories.forEach { category in
                lines.append("- \(category.section): \(category.label), \(category.size), \(category.items) items")
            }
        }

        if !warnings.isEmpty {
            lines.append("")
            lines.append("Warnings")
            warnings.forEach { warning in
                lines.append("- \(warning)")
            }
        }

        return lines.joined(separator: "\n")
    }
}

nonisolated struct InstalledApp: Codable, Equatable {
    let name: String
    let bundleID: String
    let source: String
    let uninstallName: String
    let path: String
    let size: String

    enum CodingKeys: String, CodingKey {
        case name
        case bundleID = "bundle_id"
        case source
        case uninstallName = "uninstall_name"
        case path
        case size
    }

    var sizeInBytes: Int64 {
        let normalized = size.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let pattern = #"([0-9]+(?:\.[0-9]+)?)\s*([KMGT]?B)"#
        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized)),
            let numberRange = Range(match.range(at: 1), in: normalized),
            let unitRange = Range(match.range(at: 2), in: normalized),
            let number = Double(normalized[numberRange])
        else {
            return 0
        }

        let multiplier: Double
        switch String(normalized[unitRange]) {
        case "TB":
            multiplier = 1024 * 1024 * 1024 * 1024
        case "GB":
            multiplier = 1024 * 1024 * 1024
        case "MB":
            multiplier = 1024 * 1024
        case "KB":
            multiplier = 1024
        default:
            multiplier = 1
        }

        return Int64(number * multiplier)
    }
}

nonisolated struct UninstallPreviewSummary: Equatable {
    let appCount: String
    let estimatedSpace: String
    let fileCount: Int
    let reviewOnlyCount: Int
    let leftoverCount: Int

    var estimatedBytes: Int64? {
        StorageSizeParser.bytes(from: estimatedSpace)
    }

    static func parse(from output: String, fallbackSize: String) -> UninstallPreviewSummary {
        let estimatedSpace = firstMatch(in: output, pattern: #"would free\s+([0-9]+(?:\.[0-9]+)?\s*[KMGT]?B)"#)
            ?? firstMatch(in: output, pattern: #"Remove\s+[0-9]+\s+app,\s+([0-9]+(?:\.[0-9]+)?\s*[KMGT]?B)"#)
            ?? fallbackSize
        let appCount = firstMatch(in: output, pattern: #"Would remove\s+([0-9]+)\s+app"#) ?? "1"
        let fileCount = output.components(separatedBy: "\n").filter { $0.contains("✓") }.count
        let reviewOnlyCount = output.components(separatedBy: "\n").filter { $0.localizedCaseInsensitiveContains("Review only") }.count
        let leftoverCount = max(0, fileCount - (Int(appCount) ?? 1))
        return UninstallPreviewSummary(
            appCount: appCount,
            estimatedSpace: estimatedSpace.trimmingCharacters(in: .whitespacesAndNewlines),
            fileCount: fileCount,
            reviewOnlyCount: reviewOnlyCount,
            leftoverCount: leftoverCount
        )
    }

    private static func firstMatch(in output: String, pattern: String) -> String? {
        guard
            let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
            let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
            let range = Range(match.range(at: 1), in: output)
        else {
            return nil
        }
        return String(output[range])
    }
}

struct OptimizationPlanItem {
    let title: String
    let value: String
    let detail: String
    let action: String
    let symbolName: String
    let color: NSColor
    let targetModule: AppModule
}

nonisolated struct CLILine: Identifiable, Equatable, Sendable {
    enum Status: Equatable, Sendable {
        case ok, running, dim, warning
    }

    let id: UUID
    let text: String
    let sizeText: String?
    let status: Status

    init(_ text: String, sizeText: String? = nil, status: Status = .dim) {
        self.id = UUID()
        self.text = text
        self.sizeText = sizeText
        self.status = status
    }
}
