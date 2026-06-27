//
//  AppSortMode.swift
//  Libella
//

import Foundation

enum AppSortMode: Int, CaseIterable {
    case nameAscending
    case nameDescending
    case sizeDescending
    case sizeAscending

    var title: String {
        switch self {
        case .nameAscending:
            return "Name A-Z"
        case .nameDescending:
            return "Name Z-A"
        case .sizeDescending:
            return "Size Largest"
        case .sizeAscending:
            return "Size Smallest"
        }
    }
}
