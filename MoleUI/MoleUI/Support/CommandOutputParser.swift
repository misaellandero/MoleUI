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
