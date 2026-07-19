//
//  ViewController.swift
//  Libella
//

import Cocoa

final class ViewController: NSSplitViewController {
    private static let sidebarWidth: CGFloat = 236

    private let navigationController = SidebarViewController()
    private let contentController = ModuleContentViewController()
    private let toolbarDelegate = MainToolbarDelegate()
    private var settingsWindowController: SettingsWindowController?

    override func viewDidLoad() {
        super.viewDidLoad()
        configureSplitView()
        navigationController.onSelectionChange = { [weak self] module in
            guard let self else {
                return false
            }
            guard self.contentController.confirmNavigationAwayIfNeeded(to: module) else {
                return false
            }
            self.contentController.module = module
            self.view.window?.subtitle = module.title
            return true
        }
        navigationController.select(.overview)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        configureWindowIfNeeded()
    }

    private func configureSplitView() {
        splitView.isVertical = true
        splitView.dividerStyle = .thin

        let sidebarItem = NSSplitViewItem(sidebarWithViewController: navigationController)
        sidebarItem.minimumThickness = Self.sidebarWidth
        sidebarItem.maximumThickness = Self.sidebarWidth
        sidebarItem.canCollapse = false
        addSplitViewItem(sidebarItem)

        let contentItem = NSSplitViewItem(viewController: contentController)
        contentItem.minimumThickness = 760
        addSplitViewItem(contentItem)
    }

    private func configureWindowIfNeeded() {
        guard let window = view.window else {
            return
        }

        window.title = "Libella"
        window.subtitle = contentController.module.title
        window.minSize = NSSize(width: 820, height: 580)
        window.setContentSize(NSSize(width: 960, height: 660))
        window.styleMask.insert(.fullSizeContentView)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.toolbarStyle = .unified
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(calibratedRed: 0.035, green: 0.07, blue: 0.14, alpha: 1.0)

        if window.toolbar == nil {
            toolbarDelegate.onPrimaryAction = { [weak self] in
                self?.contentController.performPrimaryAction()
            }
            toolbarDelegate.onCancel = { [weak self] in
                self?.contentController.performCancel()
            }
            toolbarDelegate.onRefresh = { [weak self] in
                self?.contentController.performRefresh()
            }
            toolbarDelegate.onSettings = { [weak self] in
                self?.showSettingsWindow()
            }

            let toolbar = NSToolbar(identifier: .mainToolbar)
            toolbar.displayMode = .iconOnly
            toolbar.allowsUserCustomization = false
            toolbar.delegate = toolbarDelegate
            window.toolbar = toolbar
        }
    }

    private func showSettingsWindow() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showWindow(self)
        settingsWindowController?.window?.makeKeyAndOrderFront(self)
        NSApp.activate(ignoringOtherApps: true)
    }

}
