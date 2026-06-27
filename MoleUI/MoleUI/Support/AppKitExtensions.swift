//
//  AppKitExtensions.swift
//  Libella
//

import Cocoa

extension NSStackView {
    func setArrangedSubviews(_ views: [NSView]) {
        arrangedSubviews.forEach { view in
            removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        views.forEach(addArrangedSubview)
    }
}

extension NSView {
    func hasSuperview<T: NSView>(ofType type: T.Type) -> Bool {
        var current: NSView? = self
        while let view = current {
            if view is T {
                return true
            }
            current = view.superview
        }
        return false
    }
}

extension NSToolbar.Identifier {
    static let mainToolbar = NSToolbar.Identifier("MainToolbar")
}

extension NSUserInterfaceItemIdentifier {
    static let sidebarColumn = NSUserInterfaceItemIdentifier("SidebarColumn")
}
