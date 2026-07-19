//
//  AmbientCLIView.swift
//  Libella
//

import SwiftUI

struct AmbientCLIView: View {
    let lines: [CLILine]
    let isRunning: Bool
    let placeholder: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.06, green: 0.11, blue: 0.28))

            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial.opacity(0.12))

            VStack(spacing: 0) {
                LinearGradient(
                    colors: [
                        Color(red: 0.55, green: 0.36, blue: 1.0).opacity(isRunning ? 0.55 : 0.22),
                        Color(red: 0.27, green: 0.58, blue: 1.0).opacity(isRunning ? 0.40 : 0.10),
                        Color.clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 1)
                Spacer()
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))

            if lines.isEmpty {
                emptyState
            } else {
                linesScrollView
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.55, green: 0.36, blue: 1.0).opacity(isRunning ? 0.50 : 0.18),
                            Color(red: 0.27, green: 0.58, blue: 1.0).opacity(isRunning ? 0.30 : 0.10),
                            Color(red: 0.0, green: 0.82, blue: 1.0).opacity(isRunning ? 0.20 : 0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .animation(.easeInOut(duration: 0.3), value: isRunning)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(red: 0.55, green: 0.36, blue: 1.0).opacity(0.45))
                    .frame(width: 6, height: 6)
                    .shadow(color: Color(red: 0.55, green: 0.36, blue: 1.0).opacity(0.6), radius: 4)
                Text(placeholder)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.38))
            }
            HStack(spacing: 16) {
                ForEach(0..<3, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(red: 0.27, green: 0.55, blue: 1.0).opacity(0.07 + Double(i) * 0.025))
                        .frame(height: 6)
                }
            }
            .frame(maxWidth: 220)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(16)
    }

    private var linesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.element.id) { idx, line in
                        AmbientCLILineRow(
                            line: line,
                            totalLines: lines.count,
                            indexFromEnd: lines.count - 1 - idx
                        )
                        .id(line.id)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
            }
            .onChange(of: lines.count) { _, _ in
                if let last = lines.last {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

private struct AmbientCLILineRow: View {
    let line: CLILine
    let totalLines: Int
    let indexFromEnd: Int

    private var opacity: Double {
        guard line.status != .running else { return 1.0 }
        let maxAge = min(totalLines - 1, 14)
        if maxAge == 0 { return 0.82 }
        let age = Double(min(indexFromEnd, maxAge))
        return max(0.14, 0.82 - (age / Double(maxAge)) * 0.68)
    }

    private var dotColor: Color {
        switch line.status {
        case .ok:      return Color(red: 0.0, green: 0.82, blue: 0.52)
        case .running: return Color(red: 0.55, green: 0.36, blue: 1.0)
        case .dim:     return Color(red: 0.20, green: 0.45, blue: 0.90).opacity(0.50)
        case .warning: return Color(red: 1.0, green: 0.60, blue: 0.04)
        }
    }

    private var textColor: Color {
        switch line.status {
        case .ok:      return Color.white.opacity(0.80)
        case .running: return Color.white
        case .dim:     return Color.white.opacity(0.48)
        case .warning: return Color(red: 1.0, green: 0.72, blue: 0.22)
        }
    }

    private var glowRadius: CGFloat {
        switch line.status {
        case .running: return 6
        case .ok:      return 3
        default:       return 0
        }
    }

    var body: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
                .shadow(color: dotColor.opacity(glowRadius > 0 ? 0.9 : 0), radius: glowRadius)

            Text(line.text)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(textColor)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let size = line.sizeText {
                Text(size)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(
                        line.status == .warning
                            ? Color(red: 1.0, green: 0.60, blue: 0.04).opacity(0.9)
                            : Color(red: 0.55, green: 0.36, blue: 1.0)
                    )
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 3.5)
        .background(
            Group {
                if line.status == .running {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(red: 0.0, green: 0.4, blue: 1.0).opacity(0.09))
                }
            }
        )
        .opacity(opacity)
        .animation(.easeOut(duration: 0.2), value: opacity)
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .opacity
        ))
    }
}
