//
//  ModuleViewModel.swift
//  Libella
//

import Foundation

protocol ModuleViewModel: AnyObject {
    var isRunning: Bool { get }
    var statusMessage: String { get }
    var onChange: (() -> Void)? { get set }

    func activate()
    func cancel()
}
