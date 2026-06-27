//
//  AppCatalogViews.swift
//  Libella
//

import Cocoa
import SwiftUI

final class InstalledAppCardView: NSView {
    let uninstallName: String
    private let onSelect: (InstalledAppCardView) -> Void

    init(
        app: InstalledApp,
        isSelected: Bool,
        onSelect: @escaping (InstalledAppCardView) -> Void
    ) {
        uninstallName = app.uninstallName
        self.onSelect = onSelect
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.backgroundColor = (isSelected ? NSColor.selectedControlColor.withAlphaComponent(0.12) : NSColor.controlBackgroundColor).cgColor
        layer?.borderWidth = isSelected ? 1 : 0
        layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.45).cgColor

        let iconView = NSImageView(image: NSWorkspace.shared.icon(forFile: app.path))
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let nameField = NSTextField(labelWithString: app.name)
        nameField.font = .systemFont(ofSize: 15, weight: .semibold)
        nameField.lineBreakMode = .byTruncatingTail

        let metaField = NSTextField(labelWithString: "\(app.size) · \(app.source)")
        metaField.font = .systemFont(ofSize: 12)
        metaField.textColor = .secondaryLabelColor

        let pathField = NSTextField(labelWithString: app.path)
        pathField.font = .systemFont(ofSize: 11)
        pathField.textColor = .tertiaryLabelColor
        pathField.lineBreakMode = .byTruncatingMiddle

        let textStack = NSStackView(views: [nameField, metaField, pathField])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 3
        textStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconView)
        addSubview(textStack)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 92),
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 52),
            iconView.heightAnchor.constraint(equalToConstant: 52),

            textStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 14),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            textStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func mouseDown(with event: NSEvent) {
        onSelect(self)
    }
}

final class TronLoopBorderHostView: NSView {
    init(cornerRadius: CGFloat, lineWidth: CGFloat) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        let hostingView = NSHostingView(rootView: TronLoopBorderView(cornerRadius: cornerRadius, lineWidth: lineWidth))
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

struct AmbientParticleBackdrop: View {
    let seed: Double
    let intensity: Double

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 24.0)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                guard size.width > 0, size.height > 0 else {
                    return
                }

                for index in 0..<18 {
                    let n = Double(index)
                    let speedA = 0.18 + fract(seed * 0.17 + n * 0.11) * 0.34
                    let speedB = 0.13 + fract(seed * 0.23 + n * 0.07) * 0.29
                    let phase = seed * 4.7 + n * 1.618
                    let drift = sin(time * (0.11 + n * 0.006) + phase) * 0.08
                    let xWave = sin(time * speedA + phase) * 0.34 + sin(time * speedB + phase * 0.41) * 0.18
                    let yWave = cos(time * (speedB * 1.37) + phase * 0.73) * 0.28 + sin(time * speedA * 0.67 + phase) * 0.12
                    let x = size.width * (0.5 + xWave + drift)
                    let y = size.height * (0.5 + yWave - drift * 0.6)
                    let radius = CGFloat(28 + fract(seed + n * 0.37) * 72)
                    let hue = 0.48 + fract(seed * 0.09 + n * 0.13) * 0.18
                    let opacity = (0.055 + fract(seed * 0.31 + n * 0.19) * 0.11) * intensity
                    let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(Color(hue: hue, saturation: 0.82, brightness: 1.0).opacity(opacity))
                    )
                }
            }
            .blur(radius: 16)
        }
    }

    private func fract(_ value: Double) -> Double {
        value - floor(value)
    }
}

struct GlobalAmbientBackgroundView: View {
    let isEnabled: Bool

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            if isEnabled {
                AmbientParticleBackdrop(seed: 12.7, intensity: 1.15)
                    .opacity(0.85)
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.42)
            }
        }
        .ignoresSafeArea()
    }
}

struct TronLoopBorderView: View {
    let cornerRadius: CGFloat
    let lineWidth: CGFloat

    var body: some View {
        Group {
            if VisualSettings.tronLinesEnabled {
                TimelineView(.animation) { context in
                    let time = context.date.timeIntervalSinceReferenceDate
                    let phase = (time * 0.10 + sin(time * 0.08) * 0.035).truncatingRemainder(dividingBy: 1)
                    let span = 0.34 + max(0, sin(time * 0.13)) * 0.22
                    ZStack {
                        movingStroke(phase: phase, span: span)
                            .blur(radius: 10)
                            .opacity(0.36)
                        movingStroke(phase: phase, span: span)
                            .blur(radius: 4)
                            .opacity(0.18)
                    }
                    .padding(lineWidth)
                }
            }
        }
    }

    @ViewBuilder
    private func movingStroke(phase: Double, span: Double) -> some View {
        let start = phase
        let end = phase + span
        let gradient = AngularGradient(
            colors: [
                .cyan.opacity(0.0),
                .cyan.opacity(0.55),
                .blue.opacity(0.42),
                .white.opacity(0.36),
                .cyan.opacity(0.0)
            ],
            center: .center,
            angle: .degrees(phase * 360)
        )

        if end <= 1 {
            RoundedRectangle(cornerRadius: cornerRadius)
                .trim(from: start, to: end)
                .stroke(gradient, style: StrokeStyle(lineWidth: lineWidth * 2.8, lineCap: .round, lineJoin: .round))
        } else {
            RoundedRectangle(cornerRadius: cornerRadius)
                .trim(from: start, to: 1)
                .stroke(gradient, style: StrokeStyle(lineWidth: lineWidth * 2.8, lineCap: .round, lineJoin: .round))
            RoundedRectangle(cornerRadius: cornerRadius)
                .trim(from: 0, to: end - 1)
                .stroke(gradient, style: StrokeStyle(lineWidth: lineWidth * 2.8, lineCap: .round, lineJoin: .round))
        }
    }
}

struct AppInspectionLoadingView: View {
    let title: String
    let detail: String

    var body: some View {
        TimelineView(.animation) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.cyan)
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                    Text("Working")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                GeometryReader { geometry in
                    let trackWidth = max(1, geometry.size.width)
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.08))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.cyan.opacity(0.22), .blue.opacity(0.78), .cyan.opacity(0.22)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: min(180, trackWidth * 0.32))
                            .offset(x: (trackWidth - min(180, trackWidth * 0.32)) * CGFloat((sin(time * 1.25) + 1) / 2))
                            .shadow(color: .cyan.opacity(0.32), radius: 8)
                    }
                }
                .frame(height: 7)

                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .windowBackgroundColor).opacity(0.35))
                }
            )
            .overlay(TronLoopBorderView(cornerRadius: 8, lineWidth: 1.0))
            .clipShape(.rect(cornerRadius: 8))
        }
    }
}

final class AppInspectorView: NSView {
    let uninstallButton = NSButton(title: "Uninstall", target: nil, action: nil)
    let cancelButton = NSButton(title: "Cancel", target: nil, action: nil)
    let revealButton = NSButton(title: "Reveal in Finder", target: nil, action: nil)

    private let cardBorderView = TronLoopBorderHostView(cornerRadius: 8, lineWidth: 1.6)
    private let iconView = NSImageView()
    private let titleField = NSTextField(labelWithString: "")
    private let detailField = NSTextField(wrappingLabelWithString: "")
    private let summaryStack = NSStackView()
    private let actionStack = NSStackView()
    private let actionBorderView = TronLoopBorderHostView(cornerRadius: 7, lineWidth: 1.2)
    private let loadingEffectContainer = NSView()
    private let loadingBorderView = TronLoopBorderHostView(cornerRadius: 8, lineWidth: 1.4)
    private var loadingEffectView: NSHostingView<AppInspectionLoadingView>?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
        configureEmpty()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configureEmpty() {
        cardBorderView.isHidden = true
        loadingEffectContainer.isHidden = true
        summaryStack.isHidden = false
        actionStack.isHidden = true
        actionBorderView.isHidden = true
        iconView.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: "App info")
        titleField.stringValue = "Select an app"
        detailField.stringValue = "Choose an app from the list below to see its size, path, bundle ID, leftovers, and uninstall details."
        summaryStack.setArrangedSubviews([
            InspectorMiniCardView(symbolName: "cursorarrow.click", title: "Waiting", value: "No app", detail: "Select an app to load its cleanup preview.")
        ])
    }

    func configureLoading(app: InstalledApp) {
        cardBorderView.isHidden = false
        loadingEffectContainer.isHidden = false
        summaryStack.isHidden = true
        actionStack.isHidden = true
        actionBorderView.isHidden = true
        loadingEffectView?.rootView = AppInspectionLoadingView(
            title: "Scanning",
            detail: "Calculating recoverable space and leftover folders."
        )
        iconView.image = NSWorkspace.shared.icon(forFile: app.path)
        titleField.stringValue = app.name
        detailField.stringValue = "\(app.size) · \(app.source)\n\(app.bundleID)\n\(app.path)"
        summaryStack.setArrangedSubviews([
            InspectorLoadingCardView(symbolName: "sparkles", title: "Scanning", detail: "Measuring app plus related files."),
            InspectorLoadingCardView(symbolName: "folder.badge.gearshape", title: "Folders", detail: "Finding support, cache, container, and receipt paths."),
            InspectorLoadingCardView(symbolName: "trash", title: "Finder misses", detail: "Checking files a normal drag-to-Trash uninstall leaves behind.")
        ])
    }

    func configure(app: InstalledApp, preview: UninstallPreviewSummary?) {
        cardBorderView.isHidden = true
        loadingEffectContainer.isHidden = true
        summaryStack.isHidden = false
        iconView.image = NSWorkspace.shared.icon(forFile: app.path)
        titleField.stringValue = app.name
        detailField.stringValue = "\(app.size) · \(app.source)\n\(app.bundleID)\n\(app.path)"
        if let preview {
            actionStack.isHidden = false
            actionBorderView.isHidden = false
            summaryStack.setArrangedSubviews([
                InspectorMiniCardView(symbolName: "externaldrive.badge.checkmark", title: "App size", value: app.size, animatedBytes: app.sizeInBytes, detail: "Size of the app bundle itself."),
                InspectorMiniCardView(symbolName: "sparkles", title: "Can free", value: preview.estimatedSpace, animatedBytes: preview.estimatedBytes, detail: "Total space from the app and related files found by preview."),
                InspectorMiniCardView(symbolName: "folder.badge.gearshape", title: "Paths", value: "\(preview.fileCount)", animatedNumber: preview.fileCount, detail: "App bundle plus leftover folders or files detected."),
                InspectorMiniCardView(symbolName: "wand.and.stars", title: "Leftovers", value: "\(preview.leftoverCount)", animatedNumber: preview.leftoverCount, detail: "Support files, caches, containers, launch items, or receipts."),
                InspectorMiniCardView(symbolName: "eye", title: "Review-only", value: "\(preview.reviewOnlyCount)", animatedNumber: preview.reviewOnlyCount, detail: "Items shown for awareness, not removed automatically.")
            ])
        } else {
            actionStack.isHidden = true
            actionBorderView.isHidden = true
            summaryStack.setArrangedSubviews([
                InspectorLoadingCardView(symbolName: "sparkles", title: "Scanning", detail: "Calculating recoverable space and leftover folders.")
            ])
        }
    }

    private func configure() {
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        cardBorderView.translatesAutoresizingMaskIntoConstraints = false
        cardBorderView.isHidden = true

        loadingEffectContainer.translatesAutoresizingMaskIntoConstraints = false
        loadingEffectContainer.wantsLayer = true
        loadingEffectContainer.layer?.cornerRadius = 8
        loadingEffectContainer.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.28).cgColor
        loadingBorderView.translatesAutoresizingMaskIntoConstraints = false

        let loadingHost = NSHostingView(rootView: AppInspectionLoadingView(title: "Scanning", detail: "Calculating recoverable space and leftover folders."))
        loadingHost.translatesAutoresizingMaskIntoConstraints = false
        loadingEffectContainer.addSubview(loadingBorderView)
        loadingEffectContainer.addSubview(loadingHost)
        loadingEffectView = loadingHost

        uninstallButton.bezelStyle = .rounded
        uninstallButton.controlSize = .large
        uninstallButton.image = NSImage(systemSymbolName: "trash.fill", accessibilityDescription: "Uninstall")
        uninstallButton.imagePosition = .imageLeading
        uninstallButton.contentTintColor = .systemCyan

        cancelButton.bezelStyle = .rounded
        cancelButton.controlSize = .large
        cancelButton.contentTintColor = .secondaryLabelColor

        revealButton.bezelStyle = .rounded
        revealButton.controlSize = .large
        revealButton.image = NSImage(systemSymbolName: "finder", accessibilityDescription: "Reveal in Finder")
        revealButton.imagePosition = .imageLeading

        actionStack.orientation = .horizontal
        actionStack.alignment = .centerY
        actionStack.spacing = 8
        actionStack.addArrangedSubview(revealButton)
        actionStack.addArrangedSubview(uninstallButton)
        actionStack.addArrangedSubview(cancelButton)
        actionStack.translatesAutoresizingMaskIntoConstraints = false
        actionStack.isHidden = true
        actionBorderView.translatesAutoresizingMaskIntoConstraints = false
        actionBorderView.isHidden = true

        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false

        titleField.font = .systemFont(ofSize: 16, weight: .semibold)
        detailField.font = .systemFont(ofSize: 12)
        detailField.textColor = .secondaryLabelColor
        summaryStack.orientation = .horizontal
        summaryStack.alignment = .top
        summaryStack.distribution = .fillEqually
        summaryStack.spacing = 10
        summaryStack.translatesAutoresizingMaskIntoConstraints = false

        let textStack = NSStackView(views: [titleField, detailField])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 5
        textStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconView)
        addSubview(textStack)
        addSubview(summaryStack)
        addSubview(loadingEffectContainer)
        addSubview(actionStack)
        addSubview(actionBorderView)
        addSubview(cardBorderView)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 258),
            cardBorderView.leadingAnchor.constraint(equalTo: leadingAnchor),
            cardBorderView.trailingAnchor.constraint(equalTo: trailingAnchor),
            cardBorderView.topAnchor.constraint(equalTo: topAnchor),
            cardBorderView.bottomAnchor.constraint(equalTo: bottomAnchor),
            loadingBorderView.leadingAnchor.constraint(equalTo: loadingEffectContainer.leadingAnchor),
            loadingBorderView.trailingAnchor.constraint(equalTo: loadingEffectContainer.trailingAnchor),
            loadingBorderView.topAnchor.constraint(equalTo: loadingEffectContainer.topAnchor),
            loadingBorderView.bottomAnchor.constraint(equalTo: loadingEffectContainer.bottomAnchor),
            loadingHost.leadingAnchor.constraint(equalTo: loadingEffectContainer.leadingAnchor),
            loadingHost.trailingAnchor.constraint(equalTo: loadingEffectContainer.trailingAnchor),
            loadingHost.topAnchor.constraint(equalTo: loadingEffectContainer.topAnchor),
            loadingHost.bottomAnchor.constraint(equalTo: loadingEffectContainer.bottomAnchor),

            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            iconView.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            iconView.widthAnchor.constraint(equalToConstant: 56),
            iconView.heightAnchor.constraint(equalToConstant: 56),
            textStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 16),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: actionStack.leadingAnchor, constant: -16),
            textStack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            actionStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            actionStack.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            actionBorderView.leadingAnchor.constraint(equalTo: actionStack.leadingAnchor, constant: -8),
            actionBorderView.trailingAnchor.constraint(equalTo: actionStack.trailingAnchor, constant: 8),
            actionBorderView.topAnchor.constraint(equalTo: actionStack.topAnchor, constant: -6),
            actionBorderView.bottomAnchor.constraint(equalTo: actionStack.bottomAnchor, constant: 6),

            loadingEffectContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            loadingEffectContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            loadingEffectContainer.topAnchor.constraint(equalTo: textStack.bottomAnchor, constant: 14),
            loadingEffectContainer.heightAnchor.constraint(equalToConstant: 116),

            summaryStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            summaryStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            summaryStack.topAnchor.constraint(equalTo: textStack.bottomAnchor, constant: 14),
            summaryStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -16)
        ])
    }
}

final class InspectorMiniCardView: NSView {
    init(symbolName: String, title: String, value: String, animatedBytes: Int64? = nil, animatedNumber: Int? = nil, detail: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.62).cgColor

        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: title)
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        iconView.contentTintColor = .controlAccentColor

        let titleField = NSTextField(labelWithString: title)
        titleField.font = .systemFont(ofSize: 11, weight: .medium)
        titleField.textColor = .secondaryLabelColor

        let valueField = NSTextField(labelWithString: value)
        valueField.font = .systemFont(ofSize: 23, weight: .bold)
        valueField.lineBreakMode = .byTruncatingTail
        valueField.maximumNumberOfLines = 1
        valueField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        if let animatedBytes {
            valueField.stringValue = ByteCountFormatter.storageString(from: 0)
            animateValueField(valueField, targetBytes: animatedBytes)
        } else if let animatedNumber {
            valueField.stringValue = "0"
            animateValueField(valueField, targetNumber: animatedNumber)
        }

        let detailField = NSTextField(wrappingLabelWithString: detail)
        detailField.font = .systemFont(ofSize: 11)
        detailField.textColor = .secondaryLabelColor
        detailField.maximumNumberOfLines = 3

        let header = NSStackView(views: [iconView, titleField])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 6

        let stack = NSStackView(views: [header, valueField, detailField])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 5
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 104),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -10)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func animateValueField(_ valueField: NSTextField, targetBytes: Int64) {
        let duration = 0.85
        let steps = 28
        for step in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + duration * Double(step) / Double(steps)) {
                let progress = Self.easeOutCubic(Double(step) / Double(steps))
                let nextValue = Double(targetBytes) * progress
                valueField.stringValue = ByteCountFormatter.storageString(from: Int64(nextValue))
            }
        }
    }

    private func animateValueField(_ valueField: NSTextField, targetNumber: Int) {
        let duration = 0.75
        let steps = max(12, min(28, targetNumber + 8))
        for step in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + duration * Double(step) / Double(steps)) {
                let progress = Self.easeOutCubic(Double(step) / Double(steps))
                valueField.stringValue = "\(Int(round(Double(targetNumber) * progress)))"
            }
        }
    }

    private static func easeOutCubic(_ value: Double) -> Double {
        1 - pow(1 - value, 3)
    }
}

final class InspectorLoadingCardView: NSView {
    private var loadingEffectView: NSHostingView<OperationEffectView>?

    init(symbolName: String, title: String, detail: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.62).cgColor

        let borderView = TronLoopBorderHostView(cornerRadius: 8, lineWidth: 1.1)
        borderView.translatesAutoresizingMaskIntoConstraints = false

        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: title)
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        iconView.contentTintColor = .controlAccentColor

        let titleField = NSTextField(labelWithString: title)
        titleField.font = .systemFont(ofSize: 11, weight: .medium)
        titleField.textColor = .secondaryLabelColor

        let detailField = NSTextField(wrappingLabelWithString: detail)
        detailField.font = .systemFont(ofSize: 11)
        detailField.textColor = .secondaryLabelColor
        detailField.maximumNumberOfLines = 3

        let loadingHost = NSHostingView(rootView: OperationEffectView(title: "Scanning", subtitle: ""))
        loadingHost.translatesAutoresizingMaskIntoConstraints = false
        loadingEffectView = loadingHost

        let header = NSStackView(views: [iconView, titleField])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 6

        let stack = NSStackView(views: [header, loadingHost, detailField])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 5
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(borderView)
        addSubview(stack)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 104),
            borderView.leadingAnchor.constraint(equalTo: leadingAnchor),
            borderView.trailingAnchor.constraint(equalTo: trailingAnchor),
            borderView.topAnchor.constraint(equalTo: topAnchor),
            borderView.bottomAnchor.constraint(equalTo: bottomAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),
            loadingHost.heightAnchor.constraint(equalToConstant: 34),
            loadingHost.widthAnchor.constraint(greaterThanOrEqualToConstant: 124),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -10)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }
}

final class AppCatalogEmptyView: NSView {
    init(title: String = "Load installed apps", detail: String = "Each app will appear with its icon and removal controls.") {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: "app.dashed", accessibilityDescription: "No apps")
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 34, weight: .regular)
        iconView.contentTintColor = .secondaryLabelColor

        let titleField = NSTextField(labelWithString: title)
        titleField.font = .systemFont(ofSize: 16, weight: .semibold)

        let detailField = NSTextField(wrappingLabelWithString: detail)
        detailField.font = .systemFont(ofSize: 13)
        detailField.textColor = .secondaryLabelColor
        detailField.alignment = .center

        let stack = NSStackView(views: [iconView, titleField, detailField])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 220),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }
}

final class MetricCardView: NSView {
    init(title: String, value: String, detail: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        let titleField = NSTextField(labelWithString: title)
        titleField.font = .systemFont(ofSize: 12, weight: .medium)
        titleField.textColor = .secondaryLabelColor

        let valueField = NSTextField(labelWithString: value)
        valueField.font = .systemFont(ofSize: 22, weight: .semibold)
        valueField.lineBreakMode = .byTruncatingTail

        let detailField = NSTextField(wrappingLabelWithString: detail)
        detailField.font = .systemFont(ofSize: 12)
        detailField.textColor = .secondaryLabelColor
        detailField.maximumNumberOfLines = 2

        let stack = NSStackView(views: [titleField, valueField, detailField])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 5
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(greaterThanOrEqualToConstant: 180),
            heightAnchor.constraint(equalToConstant: 118),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -14)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }
}

final class DetailRowView: NSView {
    init(symbolName: String, title: String, detail: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: title)
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        iconView.contentTintColor = .secondaryLabelColor
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let titleField = NSTextField(labelWithString: title)
        titleField.font = .systemFont(ofSize: 13, weight: .semibold)

        let detailField = NSTextField(wrappingLabelWithString: detail)
        detailField.font = .systemFont(ofSize: 13)
        detailField.textColor = .secondaryLabelColor
        detailField.maximumNumberOfLines = 2

        let textStack = NSStackView(views: [titleField, detailField])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconView)
        addSubview(textStack)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 52),
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor),
            iconView.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),

            textStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            textStack.topAnchor.constraint(equalTo: topAnchor),
            textStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }
}
