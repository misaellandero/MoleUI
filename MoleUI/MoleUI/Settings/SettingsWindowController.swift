//
//  SettingsWindowController.swift
//  Libella
//

import Cocoa

final class SettingsWindowController: NSWindowController {
    init() {
        let viewController = SettingsViewController()
        let window = NSWindow(contentViewController: viewController)
        window.title = "Settings"
        window.toolbarStyle = .unified
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 620, height: 420))
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        nil
    }
}

final class SettingsViewController: NSViewController {
    private let particlesButton = NSButton(checkboxWithTitle: "Ambient particle background", target: nil, action: nil)
    private let tronButton = NSButton(checkboxWithTitle: "Subtle border glow on actionable elements", target: nil, action: nil)

    override func loadView() {
        view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false

        let titleField = NSTextField(labelWithString: "Settings")
        titleField.font = .systemFont(ofSize: 24, weight: .semibold)

        let form = NSStackView()
        form.orientation = .vertical
        form.alignment = .leading
        form.spacing = 18

        particlesButton.state = VisualSettings.particlesEnabled ? .on : .off
        particlesButton.target = self
        particlesButton.action = #selector(toggleParticles)

        tronButton.state = VisualSettings.tronLinesEnabled ? .on : .off
        tronButton.target = self
        tronButton.action = #selector(toggleTronLines)

        form.addArrangedSubview(SettingsToggleRowView(
            symbolName: "sparkles",
            control: particlesButton,
            detail: "Shows soft glowing particles behind the app glass background."
        ))
        form.addArrangedSubview(SettingsToggleRowView(
            symbolName: "rectangle.dashed",
            control: tronButton,
            detail: "Adds a slow cyan glow to active buttons, loaders, and actionable panels."
        ))

        let stack = NSStackView(views: [titleField, form])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 28)
        ])
    }

    @objc private func toggleParticles() {
        VisualSettings.particlesEnabled = particlesButton.state == .on
    }

    @objc private func toggleTronLines() {
        VisualSettings.tronLinesEnabled = tronButton.state == .on
    }
}

final class SettingsToggleRowView: NSView {
    init(symbolName: String, control: NSButton, detail: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: control.title)
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)
        iconView.contentTintColor = .controlAccentColor
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let detailField = NSTextField(wrappingLabelWithString: detail)
        detailField.font = .systemFont(ofSize: 13)
        detailField.textColor = .secondaryLabelColor

        control.font = .systemFont(ofSize: 14, weight: .semibold)

        let textStack = NSStackView(views: [control, detailField])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 3
        textStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconView)
        addSubview(textStack)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 58),
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor),
            iconView.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
            textStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            textStack.topAnchor.constraint(equalTo: topAnchor),
            textStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }
}
