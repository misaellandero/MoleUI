//
//  String+ANSI.swift
//  Libella
//

import Foundation

extension String {
    func strippingANSISequences() -> String {
        let pattern = #"\u{001B}\[[0-9;]*[A-Za-z]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return self
        }
        let range = NSRange(startIndex..., in: self)
        return regex.stringByReplacingMatches(in: self, range: range, withTemplate: "")
    }
}
