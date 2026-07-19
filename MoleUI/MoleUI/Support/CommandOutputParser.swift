//
//  CommandOutputParser.swift
//  Libella
//

import Foundation

enum CommandOutputParser {
    static func compactProgressLine(from text: String) -> String? {
        let lines = text
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
            .map { line in
                line
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            }
            .filter { !$0.isEmpty }

        guard var line = lines.last else {
            return nil
        }

        if line.count > 180 {
            line = "..." + line.suffix(177)
        }
        return line
    }

    static func parseCLILines(from text: String) -> [CLILine] {
        let sizePattern = #"([0-9]+(?:\.[0-9]+)?\s*(?:KB|MB|GB|TB|bytes?))"#
        let sizeRegex = try? NSRegularExpression(pattern: sizePattern, options: [.caseInsensitive])

        return text
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { rawLine in
                var line = rawLine.strippingANSISequences()

                var sizeText: String?
                if let regex = sizeRegex {
                    let range = NSRange(line.startIndex..., in: line)
                    if let match = regex.matches(in: line, range: range).last,
                       let matchRange = Range(match.range(at: 1), in: line),
                       line.hasSuffix(String(line[matchRange])) {
                        sizeText = String(line[matchRange])
                        line = line[line.startIndex..<matchRange.lowerBound]
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }

                let lower = line.lowercased()
                let status: CLILine.Status
                if line.hasPrefix("✓") || line.hasPrefix("✔") || lower.contains("cleared") || lower.contains("removed") || lower.contains("freed") || lower.contains("done") || lower.contains("completed") {
                    status = .ok
                } else if lower.contains("warning") || lower.contains("skip") || lower.contains("protected") {
                    status = .warning
                } else {
                    status = .dim
                }

                let cleanText = line
                    .replacingOccurrences(of: "^[✓✔→▸•➜]\\s*", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                return CLILine(cleanText.isEmpty ? line : cleanText, sizeText: sizeText, status: status)
            }
    }

    static func largestStorageValue(in text: String) -> Int64? {
        let pattern = #"([0-9]+(?:\.[0-9]+)?)\s*([KMGT]?I?B|bytes?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match -> Int64? in
            guard
                let valueRange = Range(match.range(at: 1), in: text),
                let unitRange = Range(match.range(at: 2), in: text),
                let value = Double(text[valueRange])
            else {
                return nil
            }

            let unit = text[unitRange].lowercased()
            let multiplier: Double
            switch unit {
            case "kb", "kib": multiplier = 1024
            case "mb", "mib": multiplier = 1024 * 1024
            case "gb", "gib": multiplier = 1024 * 1024 * 1024
            case "tb", "tib": multiplier = 1024 * 1024 * 1024 * 1024
            default:           multiplier = 1
            }
            return Int64(value * multiplier)
        }.max()
    }
}
