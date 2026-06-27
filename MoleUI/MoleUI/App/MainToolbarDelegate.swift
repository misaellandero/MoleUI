//
//  MainToolbarDelegate.swift
//  Libella
//

import Cocoa

final class MainToolbarDelegate: NSObject, NSToolbarDelegate {
    var onPrimaryAction: (() -> Void)?
    var onCancel: (() -> Void)?
    var onRefresh: (() -> Void)?
    var onSettings: (() -> Void)?

    enum Item {
        static let scan = NSToolbarItem.Identifier("Scan")
        static let cancel = NSToolbarItem.Identifier("Cancel")
        static let refresh = NSToolbarItem.Identifier("Refresh")
        static let settings = NSToolbarItem.Identifier("Settings")
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.sidebarTrackingSeparator, .flexibleSpace, Item.cancel, Item.settings]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.sidebarTrackingSeparator, .flexibleSpace, Item.cancel, Item.settings]
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
        case Item.scan:
            return toolbarItem(identifier: itemIdentifier, label: "Run", symbolName: "play.fill", action: #selector(primaryActionClicked))
        case Item.cancel:
            return toolbarItem(identifier: itemIdentifier, label: "Cancel", symbolName: "xmark", action: #selector(cancelClicked))
        case Item.refresh:
            return toolbarItem(identifier: itemIdentifier, label: "Refresh", symbolName: "arrow.clockwise", action: #selector(refreshClicked))
        case Item.settings:
            return toolbarItem(identifier: itemIdentifier, label: "Settings", symbolName: "gearshape", action: #selector(settingsClicked))
        default:
            return nil
        }
    }

    @objc private func primaryActionClicked() {
        onPrimaryAction?()
    }

    @objc private func cancelClicked() {
        onCancel?()
    }

    @objc private func refreshClicked() {
        onRefresh?()
    }

    @objc private func settingsClicked() {
        onSettings?()
    }

    private func toolbarItem(identifier: NSToolbarItem.Identifier, label: String, symbolName: String, action: Selector) -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.label = label
        item.paletteLabel = label
        item.toolTip = label
        item.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: label)
        item.target = self
        item.action = action
        return item
    }
}
