//
//  DashboardViews.swift
//  Libella
//

import Cocoa
import SwiftUI

final class DiskSpaceSummaryHostView: NSView {
    init(
        summary: DiskSpaceSummary,
        cleanupStats: CleanupStatsStore,
        reclaimableSpace: String?,
        reclaimableKB: Int?,
        isScanning: Bool,
        canFreeSpace: Bool,
        celebrationID: Int,
        onFreeSpace: @escaping () -> Void
    ) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let hostingView = NSHostingView(rootView: DiskSpaceSummaryView(
            summary: summary,
            cleanupStats: cleanupStats,
            reclaimableSpace: reclaimableSpace,
            reclaimableKB: reclaimableKB,
            isScanning: isScanning,
            canFreeSpace: canFreeSpace,
            celebrationID: celebrationID,
            onFreeSpace: onFreeSpace
        ))
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostingView)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 272),
            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }
}

struct DiskSpaceSummaryView: View {
    let summary: DiskSpaceSummary
    let cleanupStats: CleanupStatsStore
    let reclaimableSpace: String?
    let reclaimableKB: Int?
    let isScanning: Bool
    let canFreeSpace: Bool
    let celebrationID: Int
    let onFreeSpace: () -> Void

    private var projectedAvailableText: String? {
        guard let reclaimableKB else {
            return nil
        }
        return ByteCountFormatter.storageString(from: summary.availableBytes + Int64(reclaimableKB) * 1024)
    }

    var body: some View {
        Group {
            if isScanning {
                TimelineView(.periodic(from: .now, by: 1.0 / 24.0)) { context in
                    diskSpaceContent(time: context.date.timeIntervalSinceReferenceDate)
                }
            } else {
                diskSpaceContent(time: 0)
            }
        }
    }

    @ViewBuilder
    private func diskSpaceContent(time: TimeInterval) -> some View {
        VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Disk space")
                            .font(.system(size: 20, weight: .semibold))
                        Text("Available space updates while scans are running.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: isScanning ? "waveform.path.ecg" : "externaldrive.fill")
                        Text(isScanning ? "Scanning" : "Live")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isScanning ? .cyan : .green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color(nsColor: .controlBackgroundColor)))
                }

                HStack(spacing: 12) {
                    diskMetric(title: "Available now", value: summary.availableText, detail: "Across visible volumes", symbol: "internaldrive")
                    diskMetric(
                        title: "Could free",
                        value: reclaimableSpace ?? (isScanning ? "Calculating" : "Not scanned"),
                        detail: projectedAvailableText.map { "Projected available: \($0)" } ?? "Run a clean preview",
                        symbol: "sparkles",
                        actionTitle: "Free Space",
                        isActionEnabled: canFreeSpace,
                        celebrationID: celebrationID,
                        action: onFreeSpace
                    )
                    diskMetric(title: "Total capacity", value: summary.totalText, detail: "\(summary.volumes.count) visible volume\(summary.volumes.count == 1 ? "" : "s")", symbol: "externaldrive.connected.to.line.below")
                    diskMetric(
                        title: "Freed so far",
                        value: cleanupStats.totalFreedText,
                        detail: "\(cleanupStats.uninstalledAppCount) apps, \(cleanupStats.cleanRunCount) clean runs",
                        symbol: "chart.bar.fill"
                    )
                }

                VStack(spacing: 8) {
                    ForEach(summary.volumes.prefix(4)) { volume in
                        volumeRow(volume, time: time)
                    }
                    if summary.volumes.count > 4 {
                        Text("+\(summary.volumes.count - 4) more volumes")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                if !cleanupStats.recentApps.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "trash.circle.fill")
                            .foregroundStyle(.cyan)
                        Text("Recently removed apps")
                            .font(.system(size: 12, weight: .semibold))
                        Text(cleanupStats.recentApps.joined(separator: ", "))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    if VisualSettings.particlesEnabled {
                        AmbientParticleBackdrop(seed: 1.35, intensity: isScanning ? 0.55 : 0.28)
                    }
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.72))
                }
                .clipShape(.rect(cornerRadius: 8))
            )
            .overlay(
                Group {
                    if isScanning {
                        TronLoopBorderView(cornerRadius: 8, lineWidth: 1.4)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    }
                }
            )
    }

    private func diskMetric(
        title: String,
        value: String,
        detail: String,
        symbol: String,
        actionTitle: String? = nil,
        isActionEnabled: Bool = false,
        celebrationID: Int = 0,
        action: (() -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .foregroundStyle(.cyan)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if let actionTitle, let action {
                CelebrationButton(title: actionTitle, isEnabled: isActionEnabled, celebrationID: celebrationID, action: action)
                    .padding(.top, 4)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: actionTitle == nil ? 98 : 132, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .windowBackgroundColor).opacity(0.62)))
    }

    private func volumeRow(_ volume: DiskVolumeSummary, time: TimeInterval) -> some View {
        let pulse = isScanning ? 0.25 + 0.35 * max(0, sin(time * 2.3)) : 0
        return HStack(spacing: 10) {
            Text(volume.name)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .frame(width: 150, alignment: .leading)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.08))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [.cyan.opacity(0.75 + pulse), .blue.opacity(0.6 + pulse)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(6, geometry.size.width * volume.usedFraction))
                }
            }
            .frame(height: 8)
            Text(ByteCountFormatter.storageString(from: volume.availableBytes))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 82, alignment: .trailing)
        }
    }
}

struct CelebrationButton: View {
    let title: String
    let isEnabled: Bool
    let celebrationID: Int
    let action: () -> Void

    @State private var activeCelebrationID = 0
    @State private var celebrationStartedAt = Date.distantPast

    var body: some View {
        TimelineView(.animation) { context in
            let elapsed = context.date.timeIntervalSince(celebrationStartedAt)
            let isCelebrating = activeCelebrationID == celebrationID && celebrationID > 0 && elapsed < 1.25

            Button(action: action) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                    Text(title)
                }
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                .background(
                    Capsule()
                        .fill(isEnabled ? Color.cyan.opacity(0.18) : Color.primary.opacity(0.06))
                )
                .foregroundStyle(isEnabled ? .cyan : .secondary)
                .overlay(
                    Capsule()
                        .stroke(isEnabled ? Color.cyan.opacity(0.45) : Color.primary.opacity(0.08), lineWidth: 1)
                )
                .overlay {
                    if isCelebrating {
                        SparkBurstView(progress: min(1, elapsed / 1.25))
                            .allowsHitTesting(false)
                    }
                }
                .shadow(color: isCelebrating ? .cyan.opacity(0.38) : .clear, radius: 14, x: 0, y: 0)
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
        }
        .onChange(of: celebrationID) { _, newValue in
            guard newValue > 0 else {
                return
            }
            activeCelebrationID = newValue
            celebrationStartedAt = Date()
        }
    }
}

struct SparkBurstView: View {
    let progress: Double

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
            for index in 0..<22 {
                let angle = Double(index) / 22.0 * .pi * 2
                let wave = sin(progress * .pi)
                let distance = CGFloat(14 + progress * 70) * CGFloat(0.75 + Double(index % 5) * 0.08)
                let x = center.x + cos(angle) * distance
                let y = center.y + sin(angle) * distance * 0.62
                let size = CGFloat(3 + (index % 4))
                let opacity = max(0, 1 - progress) * (0.55 + Double(index % 3) * 0.12)
                let rect = CGRect(x: x - size / 2, y: y - size / 2, width: size, height: size)
                let color: Color = index % 3 == 0 ? .white : (index % 3 == 1 ? .cyan : .blue)
                context.addFilter(.blur(radius: index % 2 == 0 ? 0.5 : 1.4))
                context.fill(Path(ellipseIn: rect), with: .color(color.opacity(opacity * wave)))
            }
        }
        .frame(width: 190, height: 110)
        .offset(y: -12)
    }
}

final class OptimizationPlanHostView: NSView {
    init(items: [OptimizationPlanItem], isRefreshing: Bool, onSelect: @escaping (AppModule) -> Void) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let hostingView = NSHostingView(rootView: OptimizationPlanView(items: items, isRefreshing: isRefreshing, onSelect: onSelect))
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostingView)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 392),
            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }
}

struct OptimizationPlanView: View {
    let items: [OptimizationPlanItem]
    let isRefreshing: Bool
    let onSelect: (AppModule) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        Group {
            if isRefreshing {
                TimelineView(.periodic(from: .now, by: 1.0 / 24.0)) { context in
                    planContent(time: context.date.timeIntervalSinceReferenceDate)
                }
            } else {
                planContent(time: 0)
            }
        }
    }

    @ViewBuilder
    private func planContent(time: TimeInterval) -> some View {
        VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Optimization checklist")
                            .font(.system(size: 20, weight: .semibold))
                        Text("A practical plan for freeing space and reviewing installed apps with preview-first safety.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: isRefreshing ? "waveform.path.ecg" : "checkmark.circle.fill")
                        Text(isRefreshing ? "Scanning" : "Ready")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isRefreshing ? .orange : .green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                }

                LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        Button {
                            onSelect(item.targetModule)
                        } label: {
                            planCard(item, index: index, time: time)
                        }
                        .buttonStyle(.plain)
                        .disabled(isRefreshing)
                        .opacity(isRefreshing ? 0.72 : 1)
                        .help(isRefreshing ? "Wait for the current scan to finish." : item.action)
                    }
                }
            }
            .padding(2)
    }

    private func planCard(_ item: OptimizationPlanItem, index: Int, time: TimeInterval) -> some View {
        let accent = Color(nsColor: item.color)
        let pulse = 0.45 + 0.35 * max(0, sin(time * 1.7 + Double(index) * 0.75))

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(accent.opacity(0.14 + pulse * 0.08))
                    Image(systemName: item.symbolName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accent)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: 14, weight: .semibold))
                    Text(item.action)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(accent)
                }
                Spacer(minLength: 8)
                Image(systemName: item.value == "Ready" || item.value == "Enabled" ? "checkmark.circle.fill" : "circle.dotted")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(accent.opacity(0.9))
            }

            Text(item.value)
                .font(.system(size: 25, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(item.detail)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 156, alignment: .leading)
        .background(
            ZStack {
                if VisualSettings.particlesEnabled {
                    AmbientParticleBackdrop(seed: Double(index) * 1.73 + 4.2, intensity: isRefreshing ? 0.5 : 0.25)
                }
                RoundedRectangle(cornerRadius: 8)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.74))
            }
            .clipShape(.rect(cornerRadius: 8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    LinearGradient(
                        colors: [
                            accent.opacity(0.18 + pulse * 0.45),
                            accent.opacity(0.05),
                            Color.primary.opacity(0.09)
                        ],
                        startPoint: UnitPoint(x: 0.1 + pulse * 0.55, y: 0),
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.35
                )
        )
        .shadow(color: accent.opacity(0.07 + pulse * 0.08), radius: 8, x: 0, y: 3)
    }
}

struct DashboardMetric {
    let title: String
    let value: String
    let detail: String
    let symbolName: String
    let color: NSColor
}

final class DashboardPanelHostView: NSView {
    init(metrics: [DashboardMetric], isRefreshing: Bool) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let hostingView = NSHostingView(rootView: DashboardPanelView(metrics: metrics, isRefreshing: isRefreshing))
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostingView)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 176),
            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }
}

struct DashboardPanelView: View {
    let metrics: [DashboardMetric]
    let isRefreshing: Bool

    var body: some View {
        Group {
            if isRefreshing {
                TimelineView(.periodic(from: .now, by: 1.0 / 24.0)) { context in
                    panelContent(time: context.date.timeIntervalSinceReferenceDate)
                }
            } else {
                panelContent(time: 0)
            }
        }
    }

    @ViewBuilder
    private func panelContent(time: TimeInterval) -> some View {
        HStack(spacing: 12) {
            ForEach(Array(metrics.enumerated()), id: \.offset) { index, metric in
                dashboardCard(metric, index: index, time: time)
            }
        }
        .padding(2)
    }

    private func dashboardCard(_ metric: DashboardMetric, index: Int, time: TimeInterval) -> some View {
        let accent = Color(nsColor: metric.color)
        let pulse = 0.45 + 0.35 * max(0, sin(time * 1.8 + Double(index)))

        return VStack(alignment: .leading, spacing: 9) {
            HStack {
                Image(systemName: metric.symbolName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(accent)
                Spacer()
                if isRefreshing {
                    Circle()
                        .fill(accent.opacity(0.35 + pulse * 0.5))
                        .frame(width: 8, height: 8)
                        .scaleEffect(0.9 + pulse * 0.35)
                }
            }
            Text(metric.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Text(metric.value)
                .font(.system(size: 24, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(metric.detail)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(15)
        .frame(maxWidth: .infinity, minHeight: 160, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    LinearGradient(
                        colors: [
                            accent.opacity(0.15 + pulse * 0.45),
                            accent.opacity(0.05),
                            Color.primary.opacity(0.08)
                        ],
                        startPoint: UnitPoint(x: 0.15 + pulse * 0.5, y: 0),
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.4
                )
        )
        .shadow(color: accent.opacity(0.08 + pulse * 0.09), radius: 8, x: 0, y: 3)
    }
}
