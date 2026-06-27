//
//  SidebarViewController.swift
//  Libella
//

import Cocoa

final class SidebarViewController: NSViewController {
    var onSelectionChange: ((AppModule) -> Bool)?

    private let scrollView = NSScrollView()
    private let tableView = NSTableView()
    private let modules = AppModule.allCases
    private var selectedModule: AppModule?
    private var isRestoringSelection = false

    override func loadView() {
        view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        configureTable()
        configureLayout()
    }

    func select(_ module: AppModule) {
        guard let row = modules.firstIndex(of: module) else {
            return
        }
        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        selectedModule = module
        _ = onSelectionChange?(module)
    }

    private func configureTable() {
        tableView.headerView = nil
        tableView.style = .sourceList
        tableView.rowHeight = 40
        tableView.usesAutomaticRowHeights = false
        tableView.delegate = self
        tableView.dataSource = self

        let column = NSTableColumn(identifier: .sidebarColumn)
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)

        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.documentView = tableView
    }

    private func configureLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: 58),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}

extension SidebarViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        modules.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let module = modules[row]
        let identifier = NSUserInterfaceItemIdentifier("SidebarCell")
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView ?? SidebarCellView()
        cell.identifier = identifier
        cell.imageView?.image = NSImage(systemSymbolName: module.symbolName, accessibilityDescription: module.title)
        cell.textField?.stringValue = module.title
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard !isRestoringSelection else {
            return
        }
        let selectedRow = tableView.selectedRow
        guard modules.indices.contains(selectedRow) else {
            return
        }
        let nextModule = modules[selectedRow]
        if onSelectionChange?(nextModule) == true {
            selectedModule = nextModule
        } else if let selectedModule, let previousRow = modules.firstIndex(of: selectedModule) {
            isRestoringSelection = true
            tableView.selectRowIndexes(IndexSet(integer: previousRow), byExtendingSelection: false)
            isRestoringSelection = false
        }
    }
}

final class SidebarCellView: NSTableCellView {
    private let iconView = NSImageView()
    private let titleField = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        imageView = iconView
        textField = titleField

        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        iconView.contentTintColor = .secondaryLabelColor
        iconView.translatesAutoresizingMaskIntoConstraints = false

        titleField.font = .systemFont(ofSize: 13, weight: .medium)
        titleField.lineBreakMode = .byTruncatingTail
        titleField.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconView)
        addSubview(titleField)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),

            titleField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            titleField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            titleField.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}
